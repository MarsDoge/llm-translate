import AppKit
import ApplicationServices
import Carbon
import Foundation

private enum AppFailure: Error, CustomStringConvertible, LocalizedError {
  case accessibilityRequired(String)
  case noSelectedText
  case cliNotFound
  case commandFailed(String)

  var description: String {
    switch self {
    case .accessibilityRequired(let appPath):
      return """
      需要在 System Settings > Privacy & Security > Accessibility 中允许本应用控制电脑。

      当前运行路径:
      \(appPath)

      如果你已经打开过权限，请先删除旧的 LLMTranslateMac 条目，再把这份 .app 重新加进去。
      """
    case .noSelectedText:
      return "没有读到选中文本。请先选中文字，再触发翻译或发音。"
    case .cliNotFound:
      return "找不到 bin/llm-translate。请从仓库内运行，或设置 LLM_TRANSLATE_CLI。"
    case .commandFailed(let message):
      return message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  var errorDescription: String? {
    description
  }
}

private struct PasteboardSnapshot {
  private struct Item {
    let values: [(NSPasteboard.PasteboardType, Data)]
  }

  private let items: [Item]

  static func capture(from pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
    let items = (pasteboard.pasteboardItems ?? []).compactMap { item -> Item? in
      let values = item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
        guard let data = item.data(forType: type) else { return nil }
        return (type, data)
      }
      return values.isEmpty ? nil : Item(values: values)
    }
    return PasteboardSnapshot(items: items)
  }

  func restore(to pasteboard: NSPasteboard = .general) {
    pasteboard.clearContents()
    let restoredItems = items.map { snapshotItem -> NSPasteboardItem in
      let item = NSPasteboardItem()
      for (type, data) in snapshotItem.values {
        item.setData(data, forType: type)
      }
      return item
    }
    if !restoredItems.isEmpty {
      pasteboard.writeObjects(restoredItems)
    }
  }
}

private final class SelectedTextReader {
  func readSelectedText() throws -> String {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    guard AXIsProcessTrustedWithOptions(options) else {
      throw AppFailure.accessibilityRequired(Bundle.main.bundlePath)
    }

    let pasteboard = NSPasteboard.general
    let snapshot = PasteboardSnapshot.capture(from: pasteboard)
    pasteboard.clearContents()
    let changeCount = pasteboard.changeCount

    postCopyShortcut()

    let deadline = Date().addingTimeInterval(1.2)
    var selectedText: String?
    while Date() < deadline {
      _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.04))
      guard pasteboard.changeCount != changeCount else { continue }
      let text = pasteboard.string(forType: .string) ?? ""
      if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        selectedText = text
        break
      }
    }

    snapshot.restore(to: pasteboard)

    guard let selectedText else {
      throw AppFailure.noSelectedText
    }
    return selectedText
  }

  private func postCopyShortcut() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }
}

private final class Translator {
  private let cliPath: String

  init() throws {
    guard let cliPath = Translator.findCLI() else {
      throw AppFailure.cliNotFound
    }
    self.cliPath = cliPath
  }

  func translate(_ text: String, completion: @escaping (Result<String, Error>) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      let result = Result { try self.runTranslation(text) }
      DispatchQueue.main.async {
        completion(result)
      }
    }
  }

  var diagnostics: String {
    var environment = ProcessInfo.processInfo.environment
    loadConfigFile(into: &environment)
    ensureHomebrewPath(in: &environment)
    applyDefaults(to: &environment)

    let provider = environment["LLM_TRANSLATE_PROVIDER"] ?? "(unset)"
    let model = environment["LLM_TRANSLATE_MODEL"] ?? "(provider default)"
    let target = environment["LLM_TRANSLATE_TARGET"] ?? "(unset)"
    let configPath = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/llm-translate/env").path
    let configExists = FileManager.default.fileExists(atPath: configPath) ? "yes" : "no"

    return """
    CLI: \(cliPath)
    Provider: \(provider)
    Model: \(model)
    Target: \(target)
    Config: \(configPath) exists: \(configExists)
    PATH: \(environment["PATH"] ?? "")
    """
  }

  private func runTranslation(_ text: String) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [cliPath]

    var environment = ProcessInfo.processInfo.environment
    loadConfigFile(into: &environment)
    ensureHomebrewPath(in: &environment)
    applyDefaults(to: &environment)
    process.environment = environment

    let input = Pipe()
    let output = Pipe()
    let error = Pipe()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = error

    try process.run()
    input.fileHandleForWriting.write(Data(text.utf8))
    try input.fileHandleForWriting.close()

    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = error.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let stdout = String(data: outputData, encoding: .utf8) ?? ""
    if process.terminationStatus == 0 {
      return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let stderr = String(data: errorData, encoding: .utf8) ?? ""
    throw AppFailure.commandFailed("""
    CLI failed with exit code \(process.terminationStatus).

    \(diagnostics)

    stderr:
    \(stderr.isEmpty ? "(empty)" : stderr)

    stdout:
    \(stdout.isEmpty ? "(empty)" : stdout)
    """)
  }

  private func applyDefaults(to environment: inout [String: String]) {
    if environment["LLM_TRANSLATE_PROVIDER"] == nil {
      environment["LLM_TRANSLATE_PROVIDER"] = "mymemory"
    }
    if environment["LLM_TRANSLATE_TARGET"] == nil {
      environment["LLM_TRANSLATE_TARGET"] = "Simplified Chinese"
    }
  }

  private func loadConfigFile(into environment: inout [String: String]) {
    let configURL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/llm-translate/env")
    guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
      return
    }

    for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      guard !line.isEmpty, !line.hasPrefix("#"), let separator = line.firstIndex(of: "=") else {
        continue
      }

      let key = line[..<separator].trimmingCharacters(in: .whitespaces)
      var value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
      if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
        value.removeFirst()
        value.removeLast()
      }
      if !key.isEmpty && environment[key] == nil {
        environment[key] = value
      }
    }
  }

  private func ensureHomebrewPath(in environment: inout [String: String]) {
    let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    guard let path = environment["PATH"], !path.isEmpty else {
      environment["PATH"] = defaultPath
      return
    }

    var parts = path.split(separator: ":").map(String.init)
    for entry in ["/opt/homebrew/bin", "/usr/local/bin"] where !parts.contains(entry) {
      parts.insert(entry, at: 0)
    }
    environment["PATH"] = parts.joined(separator: ":")
  }

  private static func findCLI() -> String? {
    let fileManager = FileManager.default
    let environment = ProcessInfo.processInfo.environment

    if let configuredPath = environment["LLM_TRANSLATE_CLI"], fileManager.fileExists(atPath: configuredPath) {
      return configuredPath
    }
    if let bundledPath = Bundle.main.resourceURL?
      .appendingPathComponent("llm-translate/bin/llm-translate").path,
       fileManager.fileExists(atPath: bundledPath) {
      return bundledPath
    }
    if let cliPath = findUpward(from: fileManager.currentDirectoryPath) {
      return cliPath
    }
    if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent().path,
       let cliPath = findUpward(from: executableDirectory) {
      return cliPath
    }
    return nil
  }

  private static func findUpward(from startPath: String) -> String? {
    guard !startPath.isEmpty else { return nil }

    var path = (startPath as NSString).standardizingPath
    let fileManager = FileManager.default

    for _ in 0..<64 {
      let candidate = (path as NSString).appendingPathComponent("bin/llm-translate")
      if fileManager.fileExists(atPath: candidate) {
        return candidate
      }

      let parent = (path as NSString).deletingLastPathComponent
      if parent == path || parent.isEmpty {
        return nil
      }
      path = parent
    }

    return nil
  }
}

private func describe(_ error: Error) -> String {
  if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
    return description
  }
  return error.localizedDescription
}

private final class HotKeyManager {
  private let signature = OSType(0x4c544d54)
  private var callbacks: [UInt32: () -> Void] = [:]
  private var hotKeys: [EventHotKeyRef?] = []

  init() {
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData in
        guard let event, let userData else { return noErr }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID
        )
        guard status == noErr else { return status }
        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        DispatchQueue.main.async {
          manager.callbacks[hotKeyID.id]?()
        }
        return noErr
      },
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      nil
    )
  }

  func register(id: UInt32, keyCode: Int, modifiers: UInt32, callback: @escaping () -> Void) {
    callbacks[id] = callback
    let hotKeyID = EventHotKeyID(signature: signature, id: id)
    var hotKeyRef: EventHotKeyRef?
    let status = RegisterEventHotKey(
      UInt32(keyCode),
      modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
    if status == noErr {
      hotKeys.append(hotKeyRef)
    } else {
      NSLog("Failed to register hot key \(id): \(status)")
    }
  }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
  private let selectedTextReader = SelectedTextReader()
  private let translator: Translator
  private let speechSynthesizer = NSSpeechSynthesizer()
  private let hotKeyManager = HotKeyManager()
  private var statusItem: NSStatusItem?
  private var panel: NSPanel?
  private var textView: NSTextView?

  override init() {
    do {
      translator = try Translator()
    } catch {
      NSAlert(error: error).runModal()
      exit(1)
    }
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    configureStatusMenu()
    hotKeyManager.register(id: 1, keyCode: kVK_ANSI_T, modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
      self?.translateSelection()
    }
    hotKeyManager.register(id: 2, keyCode: kVK_ANSI_S, modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
      self?.speakSelection()
    }
    showHelp()
  }

  private func configureStatusMenu() {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.button?.title = "译"

    let menu = NSMenu()
    addMenuItem(to: menu, title: "Show Help", action: #selector(showHelp))
    menu.addItem(NSMenuItem.separator())
    addMenuItem(to: menu, title: "Translate Selection", action: #selector(translateSelection))
    addMenuItem(to: menu, title: "Speak Selection", action: #selector(speakSelection))
    addMenuItem(to: menu, title: "Test Translation", action: #selector(testTranslation))
    addMenuItem(to: menu, title: "Show Diagnostics", action: #selector(showDiagnostics))
    menu.addItem(NSMenuItem.separator())
    let shortcutItem = NSMenuItem(title: "Shortcuts: ⌥⌘T translate, ⌥⌘S speak", action: nil, keyEquivalent: "")
    shortcutItem.isEnabled = false
    menu.addItem(shortcutItem)
    menu.addItem(NSMenuItem.separator())
    let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    quitItem.target = NSApp
    menu.addItem(quitItem)

    statusItem.menu = menu
    self.statusItem = statusItem
  }

  private func addMenuItem(to menu: NSMenu, title: String, action: Selector) {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    menu.addItem(item)
  }

  @objc private func showHelp() {
    showPanel(
      title: "LLMTranslateMac",
      body: """
      LLMTranslateMac is running in the menu bar.

      Select text in any app, then use:

      Option + Command + T  Translate selection
      Option + Command + S  Speak selection

      You can also click the menu bar item named "译".

      Use "Test Translation" from the menu to verify provider configuration without selecting text.
      """
    )
  }

  @objc private func testTranslation() {
    showPanel(title: "Translating", body: "Translating test text...")
    translator.translate("Hello, world!") { [weak self] result in
      switch result {
      case .success(let translated):
        self?.showPanel(title: "Translation Test", body: translated)
      case .failure(let error):
        self?.showPanel(title: "Translation Test Failed", body: describe(error))
      }
    }
  }

  @objc private func showDiagnostics() {
    showPanel(title: "Diagnostics", body: translator.diagnostics)
  }

  @objc private func translateSelection() {
    do {
      let text = try selectedTextReader.readSelectedText()
      showPanel(title: "Translating", body: "Translating...")
      translator.translate(text) { [weak self] result in
        switch result {
        case .success(let translated):
          self?.showPanel(title: "Translation", body: translated)
        case .failure(let error):
          self?.showPanel(title: "Translation Failed", body: describe(error))
        }
      }
    } catch {
      showPanel(title: "Translation Failed", body: describe(error))
    }
  }

  @objc private func speakSelection() {
    do {
      let text = try selectedTextReader.readSelectedText()
      speechSynthesizer.stopSpeaking()
      speechSynthesizer.startSpeaking(text)
    } catch {
      showPanel(title: "Speak Failed", body: describe(error))
    }
  }

  private func showPanel(title: String, body: String) {
    let panel = panel ?? makePanel()
    panel.title = title
    textView?.string = body.isEmpty ? "(empty result)" : body
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    self.panel = panel
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
      styleMask: [.titled, .closable, .resizable, .utilityWindow],
      backing: .buffered,
      defer: false
    )
    panel.isReleasedWhenClosed = false
    panel.level = .floating

    let scrollView = NSScrollView(frame: panel.contentView?.bounds ?? .zero)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.borderType = .noBorder

    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.font = NSFont.systemFont(ofSize: 14)
    textView.textContainerInset = NSSize(width: 12, height: 12)
    textView.autoresizingMask = [.width]
    scrollView.documentView = textView

    panel.contentView?.addSubview(scrollView)
    if let contentView = panel.contentView {
      NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
      ])
    }

    self.textView = textView
    return panel
  }
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
