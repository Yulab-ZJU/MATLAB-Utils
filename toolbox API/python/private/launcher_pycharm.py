import os, sys, runpy, inspect

def _settrace_compat(host, port, suspend=True):
    import pydevd_pycharm as dbg
    sig = inspect.signature(dbg.settrace)
    kw = {}

    if 'port' in sig.parameters: kw['port'] = port
    if 'suspend' in sig.parameters: kw['suspend'] = suspend
    if 'safe_mode' in sig.parameters: kw['safe_mode'] = True

    if 'stdout_to_server' in sig.parameters and 'stderr_to_server' in sig.parameters:
        kw['stdout_to_server'] = True
        kw['stderr_to_server'] = True
    elif 'stdoutToServer' in sig.parameters and 'stderrToServer' in sig.parameters:
        kw['stdoutToServer'] = True
        kw['stderrToServer'] = True
    elif 'redirect_stdout' in sig.parameters and 'redirect_stderr' in sig.parameters:
        kw['redirect_stdout'] = True
        kw['redirect_stderr'] = True

    return dbg.settrace(host, **kw)

def main():
    if len(sys.argv) < 2:
        print("Usage: python launcher.py <script.py> [args...]"); sys.exit(2)

    target, target_args = sys.argv[1], sys.argv[2:]
    os.chdir(os.path.dirname(os.path.abspath(target)) or ".")
    sys.argv = [target] + target_args

    host = os.environ.get("PYCHARM_HOST", "localhost")
    port = int(os.environ.get("PYCHARM_PORT", "5678"))
    suspend = os.environ.get("PYCHARM_SUSPEND", "1") == "1"

    try:
        import pydevd_pycharm  # noqa
    except Exception:
        print("[launcher] pydevd-pycharm not installed!")
        raise

    _settrace_compat(host, port, suspend=suspend)
    runpy.run_path(target, run_name="__main__")

if __name__ == "__main__":
    main()
