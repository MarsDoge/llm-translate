#include <errno.h>
#include <gio/gio.h>
#include <gtk/gtk.h>
#include <string.h>
#include <unistd.h>

typedef struct {
  GtkWidget *window;
  GtkWidget *text_view;
  GtkWidget *status_label;
  gchar *cli_path;
  gint startup_action;
} AppState;

enum {
  STARTUP_NONE = 0,
  STARTUP_TRANSLATE_SELECTION,
  STARTUP_TRANSLATE_CLIPBOARD,
  STARTUP_SPEAK_SELECTION,
  STARTUP_TEST
};

typedef struct {
  AppState *state;
  gchar *input;
} TranslateJob;

static gboolean has_command(const gchar *name) {
  gchar *path = g_find_program_in_path(name);
  gboolean found = path != NULL;
  g_free(path);
  return found;
}

static gboolean has_nonempty_text(const gchar *text) {
  if (text == NULL) {
    return FALSE;
  }

  gchar *copy = g_strdup(text);
  gboolean nonempty = g_strstrip(copy)[0] != '\0';
  g_free(copy);
  return nonempty;
}

static void set_status(AppState *state, const gchar *message) {
  gtk_label_set_text(GTK_LABEL(state->status_label), message);
}

static void set_output(AppState *state, const gchar *title, const gchar *body) {
  GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(state->text_view));
  gchar *text = g_strdup_printf("%s\n\n%s", title, body != NULL && body[0] != '\0' ? body : "(empty result)");
  gtk_text_buffer_set_text(buffer, text, -1);
  g_free(text);
}

static gboolean run_subprocess(
    const gchar * const *argv,
    const gchar *stdin_text,
    gchar **stdout_text,
    gchar **stderr_text,
    gint *exit_status,
    GError **error) {
  GSubprocessFlags flags = G_SUBPROCESS_FLAGS_STDOUT_PIPE | G_SUBPROCESS_FLAGS_STDERR_PIPE;
  if (stdin_text != NULL) {
    flags |= G_SUBPROCESS_FLAGS_STDIN_PIPE;
  }

  GSubprocess *process = g_subprocess_newv(argv, flags, error);
  if (process == NULL) {
    return FALSE;
  }

  gboolean ok = g_subprocess_communicate_utf8(
      process,
      stdin_text,
      NULL,
      stdout_text,
      stderr_text,
      error);
  if (ok && exit_status != NULL) {
    *exit_status = g_subprocess_get_exit_status(process);
  }
  if (ok && exit_status != NULL && *exit_status != 0) {
    ok = FALSE;
  }

  g_object_unref(process);
  return ok;
}

static gchar *read_command_output(const gchar * const *argv) {
  gchar *stdout_text = NULL;
  gchar *stderr_text = NULL;
  gint exit_status = 0;
  GError *error = NULL;

  gboolean ok = run_subprocess(argv, NULL, &stdout_text, &stderr_text, &exit_status, &error);
  g_clear_error(&error);
  g_free(stderr_text);

  if (!ok || !has_nonempty_text(stdout_text)) {
    g_free(stdout_text);
    return NULL;
  }

  return stdout_text;
}

static gboolean write_command_input(const gchar * const *argv, const gchar *text) {
  gchar *stdout_text = NULL;
  gchar *stderr_text = NULL;
  gint exit_status = 0;
  GError *error = NULL;

  gboolean ok = run_subprocess(argv, text, &stdout_text, &stderr_text, &exit_status, &error);
  g_clear_error(&error);
  g_free(stdout_text);
  g_free(stderr_text);
  return ok;
}

static gboolean spawn_command(const gchar * const *argv) {
  GError *error = NULL;
  gboolean ok = g_spawn_async(
      NULL,
      (gchar **)argv,
      NULL,
      G_SPAWN_SEARCH_PATH,
      NULL,
      NULL,
      NULL,
      &error);
  g_clear_error(&error);
  return ok;
}

static gchar *read_primary_selection(void) {
  if (g_getenv("WAYLAND_DISPLAY") != NULL && has_command("wl-paste")) {
    const gchar *argv[] = {"wl-paste", "--primary", "--no-newline", NULL};
    gchar *output = read_command_output(argv);
    if (output != NULL) {
      return output;
    }
  }

  if (g_getenv("DISPLAY") != NULL && has_command("xclip")) {
    const gchar *argv[] = {"xclip", "-selection", "primary", "-o", NULL};
    gchar *output = read_command_output(argv);
    if (output != NULL) {
      return output;
    }
  }

  if (g_getenv("DISPLAY") != NULL && has_command("xsel")) {
    const gchar *argv[] = {"xsel", "--primary", "--output", NULL};
    gchar *output = read_command_output(argv);
    if (output != NULL) {
      return output;
    }
  }

  return NULL;
}

static gchar *read_clipboard(void) {
  if (g_getenv("WAYLAND_DISPLAY") != NULL && has_command("wl-paste")) {
    const gchar *argv[] = {"wl-paste", "--no-newline", NULL};
    gchar *output = read_command_output(argv);
    return output != NULL ? output : g_strdup("");
  }

  if (g_getenv("DISPLAY") != NULL && has_command("xclip")) {
    const gchar *argv[] = {"xclip", "-selection", "clipboard", "-o", NULL};
    gchar *output = read_command_output(argv);
    return output != NULL ? output : g_strdup("");
  }

  if (g_getenv("DISPLAY") != NULL && has_command("xsel")) {
    const gchar *argv[] = {"xsel", "--clipboard", "--output", NULL};
    gchar *output = read_command_output(argv);
    return output != NULL ? output : g_strdup("");
  }

  return NULL;
}

static gboolean write_clipboard(const gchar *text) {
  if (g_getenv("WAYLAND_DISPLAY") != NULL && has_command("wl-copy")) {
    const gchar *argv[] = {"wl-copy", NULL};
    return write_command_input(argv, text);
  }

  if (g_getenv("DISPLAY") != NULL && has_command("xclip")) {
    const gchar *argv[] = {"xclip", "-selection", "clipboard", NULL};
    return write_command_input(argv, text);
  }

  if (g_getenv("DISPLAY") != NULL && has_command("xsel")) {
    const gchar *argv[] = {"xsel", "--clipboard", "--input", NULL};
    return write_command_input(argv, text);
  }

  return FALSE;
}

static gboolean post_copy_shortcut(void) {
  if (g_getenv("DISPLAY") != NULL && has_command("xdotool")) {
    const gchar *argv[] = {"xdotool", "key", "--clearmodifiers", "ctrl+c", NULL};
    return spawn_command(argv);
  }

  if (g_getenv("WAYLAND_DISPLAY") != NULL && has_command("wtype")) {
    const gchar *argv[] = {"wtype", "-M", "ctrl", "c", "-m", "ctrl", NULL};
    return spawn_command(argv);
  }

  if (has_command("ydotool")) {
    const gchar *argv[] = {"ydotool", "key", "29:1", "46:1", "46:0", "29:0", NULL};
    return spawn_command(argv);
  }

  return FALSE;
}

static gchar *read_selection_via_copy(void) {
  gchar *old_clipboard = read_clipboard();
  gboolean had_clipboard = has_nonempty_text(old_clipboard);
  gchar *selected = NULL;

  write_clipboard("");
  if (!post_copy_shortcut()) {
    g_free(old_clipboard);
    return NULL;
  }

  for (guint attempt = 0; attempt < 8; attempt++) {
    g_usleep(80000);
    g_free(selected);
    selected = read_clipboard();
    if (has_nonempty_text(selected)) {
      break;
    }
  }

  if (had_clipboard) {
    write_clipboard(old_clipboard);
  } else {
    write_clipboard("");
  }
  g_free(old_clipboard);

  if (!has_nonempty_text(selected)) {
    g_free(selected);
    return NULL;
  }

  return selected;
}

static gchar *read_selected_text(void) {
  gchar *text = read_primary_selection();
  if (text != NULL) {
    return text;
  }

  return read_selection_via_copy();
}

static gchar *find_upward_cli(const gchar *start_path) {
  gchar *path = g_canonicalize_filename(start_path, NULL);

  while (path != NULL && path[0] != '\0') {
    gchar *candidate = g_build_filename(path, "bin", "llm-translate", NULL);
    if (g_file_test(candidate, G_FILE_TEST_IS_EXECUTABLE)) {
      g_free(path);
      return candidate;
    }
    g_free(candidate);

    gchar *parent = g_path_get_dirname(path);
    if (g_strcmp0(parent, path) == 0) {
      g_free(parent);
      break;
    }
    g_free(path);
    path = parent;
  }

  g_free(path);
  return NULL;
}

static gchar *find_cli(void) {
  const gchar *configured = g_getenv("LLM_TRANSLATE_CLI");
  if (configured != NULL && g_file_test(configured, G_FILE_TEST_IS_EXECUTABLE)) {
    return g_strdup(configured);
  }

  gchar *self_path = g_file_read_link("/proc/self/exe", NULL);
  if (self_path != NULL) {
    gchar *self_dir = g_path_get_dirname(self_path);
    gchar *cli_path = find_upward_cli(self_dir);
    g_free(self_dir);
    g_free(self_path);
    if (cli_path != NULL) {
      return cli_path;
    }
  }

  gchar *cwd = g_get_current_dir();
  gchar *cli_path = find_upward_cli(cwd);
  g_free(cwd);
  if (cli_path != NULL) {
    return cli_path;
  }

  return g_find_program_in_path("llm-translate");
}

static void load_config_file(void) {
  const gchar *xdg_config = g_getenv("XDG_CONFIG_HOME");
  gchar *config_path = xdg_config != NULL
      ? g_build_filename(xdg_config, "llm-translate", "env", NULL)
      : g_build_filename(g_get_home_dir(), ".config", "llm-translate", "env", NULL);
  gchar *contents = NULL;

  if (!g_file_get_contents(config_path, &contents, NULL, NULL)) {
    g_free(config_path);
    return;
  }

  gchar **lines = g_strsplit(contents, "\n", -1);
  for (gchar **cursor = lines; cursor != NULL && *cursor != NULL; cursor++) {
    gchar *line = g_strstrip(*cursor);
    if (line[0] == '\0' || line[0] == '#') {
      continue;
    }

    gchar *separator = strchr(line, '=');
    if (separator == NULL) {
      continue;
    }

    *separator = '\0';
    gchar *key = g_strstrip(line);
    gchar *value = g_strstrip(separator + 1);
    gsize value_len = strlen(value);
    if (value_len >= 2 &&
        ((value[0] == '"' && value[value_len - 1] == '"') ||
         (value[0] == '\'' && value[value_len - 1] == '\''))) {
      value[value_len - 1] = '\0';
      value++;
    }

    if (g_getenv(key) == NULL && g_regex_match_simple("^[A-Za-z_][A-Za-z0-9_]*$", key, 0, 0)) {
      g_setenv(key, value, FALSE);
    }
  }

  g_strfreev(lines);
  g_free(contents);
  g_free(config_path);
}

static void apply_defaults(void) {
  if (g_getenv("LLM_TRANSLATE_PROVIDER") == NULL && g_getenv("DEEPSEEK_API_KEY") == NULL) {
    g_setenv("LLM_TRANSLATE_PROVIDER", "mymemory", FALSE);
  }
  if (g_getenv("LLM_TRANSLATE_TARGET") == NULL) {
    g_setenv("LLM_TRANSLATE_TARGET", "Simplified Chinese", FALSE);
  }
}

static gchar *run_translation(const gchar *cli_path, const gchar *input, GError **error) {
  const gchar *argv[] = {cli_path, NULL};
  gchar *stdout_text = NULL;
  gchar *stderr_text = NULL;
  gint exit_status = 0;

  gboolean ok = run_subprocess(argv, input, &stdout_text, &stderr_text, &exit_status, error);
  if (!ok) {
    if (error != NULL && *error == NULL) {
      g_set_error(
          error,
          G_IO_ERROR,
          G_IO_ERROR_FAILED,
          "CLI failed with exit code %d.\n\nstderr:\n%s",
          exit_status,
          stderr_text != NULL && stderr_text[0] != '\0' ? stderr_text : "(empty)");
    }
    g_free(stdout_text);
    g_free(stderr_text);
    return NULL;
  }

  g_free(stderr_text);
  return stdout_text;
}

static void translate_job_free(TranslateJob *job) {
  g_free(job->input);
  g_free(job);
}

static void translate_task_thread(GTask *task, gpointer source_object, gpointer task_data, GCancellable *cancellable) {
  (void)source_object;
  (void)cancellable;

  TranslateJob *job = task_data;
  GError *error = NULL;
  gchar *translated = run_translation(job->state->cli_path, job->input, &error);
  if (translated == NULL) {
    g_task_return_error(task, error);
    return;
  }

  g_task_return_pointer(task, translated, g_free);
}

static void on_translate_done(GObject *source_object, GAsyncResult *result, gpointer user_data) {
  (void)source_object;
  AppState *state = user_data;
  GError *error = NULL;
  gchar *translated = g_task_propagate_pointer(G_TASK(result), &error);

  if (translated == NULL) {
    set_status(state, "Translation failed");
    set_output(state, "Translation Failed", error != NULL ? error->message : "Unknown error");
    g_clear_error(&error);
    return;
  }

  set_status(state, "Ready");
  set_output(state, "Translation", translated);
  g_free(translated);
}

static void start_translation(AppState *state, const gchar *input) {
  if (!has_nonempty_text(input)) {
    set_status(state, "No text to translate");
    set_output(state, "No Text", "Select text in another app or copy text to the clipboard first.");
    return;
  }

  TranslateJob *job = g_new0(TranslateJob, 1);
  job->state = state;
  job->input = g_strdup(input);

  set_status(state, "Translating...");
  set_output(state, "Translating", "Waiting for provider response...");

  GTask *task = g_task_new(NULL, NULL, on_translate_done, state);
  g_task_set_task_data(task, job, (GDestroyNotify)translate_job_free);
  g_task_run_in_thread(task, translate_task_thread);
  g_object_unref(task);
}

static void on_translate_selection(GtkButton *button, gpointer user_data) {
  (void)button;
  AppState *state = user_data;
  gchar *text = read_selected_text();
  if (text == NULL) {
    set_status(state, "No selected text");
    set_output(
        state,
        "No Selected Text",
        "Select text in another app first. On Wayland, copy the text and use Translate Clipboard if selection access is blocked.");
    return;
  }
  start_translation(state, text);
  g_free(text);
}

static void on_translate_clipboard(GtkButton *button, gpointer user_data) {
  (void)button;
  AppState *state = user_data;
  gchar *text = read_clipboard();
  if (text == NULL) {
    set_status(state, "Clipboard unavailable");
    set_output(state, "Clipboard Unavailable", "Install wl-clipboard, xclip, or xsel.");
    return;
  }
  start_translation(state, text);
  g_free(text);
}

static void on_speak_selection(GtkButton *button, gpointer user_data) {
  (void)button;
  AppState *state = user_data;
  gchar *text = read_selected_text();
  if (text == NULL) {
    set_status(state, "No selected text");
    set_output(state, "Speak Failed", "Select text first, then try again.");
    return;
  }

  gboolean ok = FALSE;
  if (has_command("spd-say")) {
    const gchar *argv[] = {"spd-say", text, NULL};
    ok = spawn_command(argv);
  } else if (has_command("espeak-ng")) {
    const gchar *argv[] = {"espeak-ng", text, NULL};
    ok = spawn_command(argv);
  } else if (has_command("espeak")) {
    const gchar *argv[] = {"espeak", text, NULL};
    ok = spawn_command(argv);
  }

  if (ok) {
    set_status(state, "Speaking");
    set_output(state, "Speaking", text);
  } else {
    set_status(state, "Speech unavailable");
    set_output(state, "Speech Unavailable", "Install speech-dispatcher, espeak-ng, or espeak.");
  }

  g_free(text);
}

static void on_test_translation(GtkButton *button, gpointer user_data) {
  (void)button;
  AppState *state = user_data;
  start_translation(state, "Hello, world!");
}

static gboolean run_startup_action(gpointer user_data) {
  AppState *state = user_data;

  switch (state->startup_action) {
    case STARTUP_TRANSLATE_SELECTION:
      on_translate_selection(NULL, state);
      break;
    case STARTUP_TRANSLATE_CLIPBOARD:
      on_translate_clipboard(NULL, state);
      break;
    case STARTUP_SPEAK_SELECTION:
      on_speak_selection(NULL, state);
      break;
    case STARTUP_TEST:
      on_test_translation(NULL, state);
      break;
    default:
      break;
  }

  state->startup_action = STARTUP_NONE;
  return G_SOURCE_REMOVE;
}

static const gchar *first_available(const gchar *a, const gchar *b, const gchar *c, const gchar *d) {
  if (a != NULL && has_command(a)) {
    return a;
  }
  if (b != NULL && has_command(b)) {
    return b;
  }
  if (c != NULL && has_command(c)) {
    return c;
  }
  if (d != NULL && has_command(d)) {
    return d;
  }
  return "none";
}

static void on_diagnostics(GtkButton *button, gpointer user_data) {
  (void)button;
  AppState *state = user_data;
  const gchar *xdg_config = g_getenv("XDG_CONFIG_HOME");
  gchar *config_path = xdg_config != NULL
      ? g_build_filename(xdg_config, "llm-translate", "env", NULL)
      : g_build_filename(g_get_home_dir(), ".config", "llm-translate", "env", NULL);
  gchar *body = g_strdup_printf(
      "CLI: %s\n"
      "Provider: %s\n"
      "Model: %s\n"
      "Target: %s\n"
      "Config: %s exists: %s\n"
      "Session: XDG_SESSION_TYPE=%s DISPLAY=%s WAYLAND_DISPLAY=%s\n\n"
      "Helpers:\n"
      "  clipboard: %s\n"
      "  copy shortcut: %s\n"
      "  speech: %s\n",
      state->cli_path,
      g_getenv("LLM_TRANSLATE_PROVIDER") != NULL ? g_getenv("LLM_TRANSLATE_PROVIDER") : "(unset)",
      g_getenv("LLM_TRANSLATE_MODEL") != NULL ? g_getenv("LLM_TRANSLATE_MODEL") : "(provider default)",
      g_getenv("LLM_TRANSLATE_TARGET") != NULL ? g_getenv("LLM_TRANSLATE_TARGET") : "(unset)",
      config_path,
      g_file_test(config_path, G_FILE_TEST_EXISTS) ? "yes" : "no",
      g_getenv("XDG_SESSION_TYPE") != NULL ? g_getenv("XDG_SESSION_TYPE") : "(unset)",
      g_getenv("DISPLAY") != NULL ? g_getenv("DISPLAY") : "(unset)",
      g_getenv("WAYLAND_DISPLAY") != NULL ? g_getenv("WAYLAND_DISPLAY") : "(unset)",
      first_available("wl-paste", "xclip", "xsel", NULL),
      first_available("xdotool", "wtype", "ydotool", NULL),
      first_available("spd-say", "espeak-ng", "espeak", NULL));

  set_status(state, "Diagnostics");
  set_output(state, "Diagnostics", body);
  g_free(body);
  g_free(config_path);
}

static GtkWidget *make_button(const gchar *label, GCallback callback, AppState *state) {
  GtkWidget *button = gtk_button_new_with_label(label);
  g_signal_connect(button, "clicked", callback, state);
  return button;
}

static void activate(GtkApplication *application, gpointer user_data) {
  AppState *state = user_data;

  state->window = gtk_application_window_new(application);
  gtk_window_set_title(GTK_WINDOW(state->window), "LLMTranslateLinux");
  gtk_window_set_default_size(GTK_WINDOW(state->window), 680, 460);

  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  gtk_container_set_border_width(GTK_CONTAINER(box), 10);
  gtk_container_add(GTK_CONTAINER(state->window), box);

  GtkWidget *toolbar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
  gtk_box_pack_start(GTK_BOX(box), toolbar, FALSE, FALSE, 0);

  gtk_box_pack_start(GTK_BOX(toolbar), make_button("Translate Selection", G_CALLBACK(on_translate_selection), state), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(toolbar), make_button("Translate Clipboard", G_CALLBACK(on_translate_clipboard), state), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(toolbar), make_button("Speak Selection", G_CALLBACK(on_speak_selection), state), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(toolbar), make_button("Test", G_CALLBACK(on_test_translation), state), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(toolbar), make_button("Diagnostics", G_CALLBACK(on_diagnostics), state), FALSE, FALSE, 0);

  GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(box), scroll, TRUE, TRUE, 0);

  state->text_view = gtk_text_view_new();
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(state->text_view), GTK_WRAP_WORD_CHAR);
  gtk_text_view_set_editable(GTK_TEXT_VIEW(state->text_view), FALSE);
  gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(state->text_view), FALSE);
  gtk_container_add(GTK_CONTAINER(scroll), state->text_view);

  state->status_label = gtk_label_new("Ready");
  gtk_label_set_xalign(GTK_LABEL(state->status_label), 0.0);
  gtk_box_pack_start(GTK_BOX(box), state->status_label, FALSE, FALSE, 0);

  set_output(state, "LLMTranslateLinux", "Select text in another app, then click Translate Selection. On Wayland, copy text and use Translate Clipboard if direct selection access is blocked.");
  gtk_widget_show_all(state->window);

  if (state->startup_action != STARTUP_NONE) {
    g_idle_add(run_startup_action, state);
  }
}

static gboolean handle_local_options(GApplication *application, GVariantDict *options, gpointer user_data) {
  (void)application;
  AppState *state = user_data;

  if (g_variant_dict_contains(options, "translate-selection")) {
    state->startup_action = STARTUP_TRANSLATE_SELECTION;
  } else if (g_variant_dict_contains(options, "translate-clipboard")) {
    state->startup_action = STARTUP_TRANSLATE_CLIPBOARD;
  } else if (g_variant_dict_contains(options, "speak-selection")) {
    state->startup_action = STARTUP_SPEAK_SELECTION;
  } else if (g_variant_dict_contains(options, "test")) {
    state->startup_action = STARTUP_TEST;
  }

  return -1;
}

int main(int argc, char **argv) {
  load_config_file();
  apply_defaults();

  AppState state = {0};
  state.cli_path = find_cli();
  if (state.cli_path == NULL) {
    g_printerr("Cannot find bin/llm-translate. Run from the repository checkout or set LLM_TRANSLATE_CLI.\n");
    return 1;
  }

  GtkApplication *application = gtk_application_new("io.github.MarsDoge.LLMTranslateLinux", G_APPLICATION_FLAGS_NONE);
  const GOptionEntry options[] = {
      {"translate-selection", 0, 0, G_OPTION_ARG_NONE, NULL, "Translate the current selection after opening", NULL},
      {"translate-clipboard", 0, 0, G_OPTION_ARG_NONE, NULL, "Translate the clipboard after opening", NULL},
      {"speak-selection", 0, 0, G_OPTION_ARG_NONE, NULL, "Speak the current selection after opening", NULL},
      {"test", 0, 0, G_OPTION_ARG_NONE, NULL, "Run a test translation after opening", NULL},
      {NULL, 0, 0, 0, NULL, NULL, NULL}};
  g_application_add_main_option_entries(G_APPLICATION(application), options);
  g_signal_connect(application, "handle-local-options", G_CALLBACK(handle_local_options), &state);
  g_signal_connect(application, "activate", G_CALLBACK(activate), &state);
  int status = g_application_run(G_APPLICATION(application), argc, argv);
  g_object_unref(application);
  g_free(state.cli_path);
  return status;
}
