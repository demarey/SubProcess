/*
 * gprocess_stdin.c
 *
 * A small reference experiment to pin down how GSubprocess behaves with stdin.
 *
 * It is fully self-contained and cross-platform (runs on both macOS and
 * Windows) by spawning *itself* in a "--child-echo" mode rather than relying on
 * `cat` (which is not present on Windows).
 *
 * Parent mode (default):
 *   - creates a GSubprocessLauncher with STDIN_PIPE | STDOUT_PIPE | STDERR_PIPE
 *   - spawns <this-exe> --child-echo
 *   - writes "hello stdin" to the child's stdin pipe
 *   - closes the stdin pipe (must deliver EOF to the child)
 *   - waits for the child to exit (g_subprocess_wait_check)
 *   - reads all of the child's stdout
 *   - asserts the child exited successfully and echoed the exact text back
 *
 * Child mode (--child-echo):
 *   - copies stdin to stdout using the plain C runtime (portable), then exits 0.
 *
 * Build (Unix/macOS):
 *   cc $(pkg-config --cflags gio-2.0) gprocess_stdin.c -o gprocess_stdin \
 *      $(pkg-config --libs gio-2.0)
 * Run: ./gprocess_stdin        -> prints PASS or FAIL
 *
 * Note: it is the closing of the stdin pipe that delivers EOF to the child. If
 * you remove g_output_stream_close() below, the child keeps waiting on stdin and
 * g_subprocess_wait_check() never returns.
 */

#include <gio/gio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int
run_child_echo (void)
{
  int c;
  while ((c = fgetc (stdin)) != EOF)
    fputc (c, stdout);
  fflush (stdout);
  return 0;
}

/* Read all of `in` (a GInputStream) into a malloc'd NUL-terminated buffer. */
static char *
read_all (GInputStream *in, gsize *out_len)
{
  GError *err = NULL;
  gsize capacity = 256, len = 0;
  char *buf = g_malloc (capacity);

  for (;;)
    {
      gsize nread;
      gchar chunk[4096];

      if (!g_input_stream_read_all (in, chunk, sizeof chunk, &nread, NULL, &err))
        {
          g_printerr ("read stdout failed: %s\n", err->message);
          g_error_free (err);
          g_free (buf);
          return NULL;
        }
      if (nread == 0)
        break;
      if (len + nread + 1 > capacity)
        {
          capacity = (len + nread + 1) * 2;
          buf = g_realloc (buf, capacity);
        }
      memcpy (buf + len, chunk, nread);
      len += nread;
    }

  buf[len] = '\0';
  if (out_len)
    *out_len = len;
  return buf;
}

static int
run_parent (const char *self_path)
{
  static const char payload[] = "hello stdin";
  GError *err = NULL;
  GSubprocessLauncher *launcher;
  GSubprocess *sub = NULL;
  const gchar *argv[3];
  gchar *child = NULL;
  GOutputStream *stdin_pipe;
  GInputStream *stdout_pipe;
  gsize bytes_written;
  char *stdout_text;
  gsize stdout_len;
  gboolean ok;

#ifdef _WIN32
  /* Windows' CreateProcess needs the .exe extension, which argv[0] omits. */
  if (!g_str_has_suffix (self_path, ".exe"))
    child = g_strdup_printf ("%s.exe", self_path);
  else
    child = (gchar *) self_path;
#else
  child = (gchar *) self_path;
#endif

  launcher = g_subprocess_launcher_new (G_SUBPROCESS_FLAGS_STDIN_PIPE |
                                        G_SUBPROCESS_FLAGS_STDOUT_PIPE |
                                        G_SUBPROCESS_FLAGS_STDERR_PIPE);

  argv[0] = child;
  argv[1] = "--child-echo";
  argv[2] = NULL;
  sub = g_subprocess_launcher_spawnv (launcher, (const gchar * const *) argv, &err);
  if (sub == NULL)
    {
      g_printerr ("spawn failed: %s\n", err->message);
      g_error_free (err);
      g_object_unref (launcher);
#ifdef _WIN32
      if (child != self_path) g_free (child);
#endif
      return 1;
    }

  stdin_pipe = g_subprocess_get_stdin_pipe (sub);
  if (!g_output_stream_write_all (stdin_pipe, payload, sizeof payload - 1,
                                  &bytes_written, NULL, &err))
    {
      g_printerr ("write stdin failed: %s\n", err->message);
      g_error_free (err);
      g_object_unref (sub);
      g_object_unref (launcher);
      return 1;
    }

  /* Closing the stdin pipe sends EOF so the child can exit. */
  if (!g_output_stream_close (stdin_pipe, NULL, &err))
    {
      g_printerr ("close stdin failed: %s\n", err->message);
      g_error_free (err);
    }

  ok = g_subprocess_wait_check (sub, NULL, &err);
  if (!ok)
    {
      g_printerr ("wait_check failed: %s\n", err->message);
      g_error_free (err);
    }

  stdout_pipe = g_subprocess_get_stdout_pipe (sub);
  stdout_text = read_all (stdout_pipe, &stdout_len);
  if (stdout_text == NULL)
    ok = FALSE;

  ok = ok && g_subprocess_get_successful (sub);
  ok = ok && stdout_text != NULL
          && stdout_len == sizeof payload - 1
          && memcmp (stdout_text, payload, sizeof payload - 1) == 0;

  if (ok)
    {
      printf ("PASS echo=\"%s\" exit=%d\n", stdout_text ? stdout_text : "(null)",
              g_subprocess_get_exit_status (sub));
    }
  else
    {
      printf ("FAIL exit=%d successful=%d echoed=\"%s\"\n",
              g_subprocess_get_exit_status (sub),
              g_subprocess_get_successful (sub) ? 1 : 0,
              stdout_text ? stdout_text : "(null)");
    }

  g_free (stdout_text);
  g_object_unref (sub);
  g_object_unref (launcher);
#ifdef _WIN32
  if (child != self_path) g_free (child);
#endif
  return ok ? 0 : 2;
}

int
main (int argc, char **argv)
{
  if (argc > 1 && strcmp (argv[1], "--child-echo") == 0)
    return run_child_echo ();
  return run_parent (argv[0]);
}
