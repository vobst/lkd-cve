import gdb


class GenericContextBP(gdb.Breakpoint):
    """
    Info: A Breakpoint that is only active in a given context.
    """

    def __init__(self, *args, **kwargs):
        """
        @attr   String      _comm       'comm' member of 'struct
                                        task_struct' of process in whose
                                        context we want to stop
        @attr   String      _condition  expression that determines if
                                        breakpoint is activated
        """
        super().__init__(*args)
        self._comm = kwargs["comm"]
        self._condition = f"""$_streq($lx_current().comm, "{self._comm}")"""

    def _condition_holds(self):
        return bool(gdb.parse_and_eval(self._condition))

    def _print_header(self, message):
        print("{}\n{}\n".format(75 * "-", message))

    def stop(self):
        # Problem: It seems like the BP.condition only influences whether
        #   gdb stops the program i.e. return value of stop(), but not if
        #   the code in stop() is executed.
        #   https://stackoverflow.com/a/56871869
        if not self._condition_holds():
            return False
        return self._stop()

    def _stop(self):
        pass
