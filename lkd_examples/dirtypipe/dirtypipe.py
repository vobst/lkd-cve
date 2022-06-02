import os

sys.path.insert(0, "/"+os.environ['PROJECTE']+"/lkd_scripts_gdb")

from lkd import session
from lkd import structs
from lkd import breakpoints


class Session(session.GenericSession):
    task = None
    pipe = None
    buf = None
    file = None
    fmap = None
    page = None


class OpenBP(breakpoints.GenericContextBP):
    def _stop(self):
        Session.file = structs.File(gdb.parse_and_eval("f"))
        if Session.file.get_filename() != "target_file":
            return False
        Session.task = structs.Task(gdb.parse_and_eval("$lx_current()").address)
        Session.fmap = structs.AddrSpace(Session.file.get_member("f_mapping"))
        Session.page = structs.Page(Session.fmap.get_member("i_pages")["xa_head"])
        self._print_header("Stage 1: open the target file")
        Session.task.print_info()
        Session.file.print_info()
        Session.fmap.print_info()
        Session.page.print_info()
        return False


class PipeFcntlBP(breakpoints.GenericContextBP):
    def _stop(self):
        Session.pipe = structs.Pipe(gdb.parse_and_eval("file")["private_data"])
        Session.buf = structs.PipeBuffer(Session.pipe.get_member("bufs"))
        self._print_header("Stage 2: create pipe")
        Session.pipe.print_info()
        Session.buf.print_info()
        return False


class PipeWriteBP(breakpoints.GenericContextBP):
    def _stop(self):
        if int(Session.buf.get_member("len")) not in {8, 18, 4096}:
            return False
        else:
            buf_page = structs.Page(Session.buf.get_member("page"))
            if int(Session.buf.get_member("len")) == 8:
                self._print_header("Stage 3.1: init pipe buffer with write")
            elif int(Session.buf.get_member("len")) == 4096:
                self._print_header("Stage 3.2: filled pipe buffer")
            else:
                self._print_header("Stage 7: writing into page cache")
                Session.fmap.print_info()
        Session.pipe.print_info()
        Session.buf.print_info()
        buf_page.print_info()
        return False


class PipeReadBP(breakpoints.GenericContextBP):
    def _stop(self):
        if int(Session.buf.get_member("len")) != 0:
            return False
        self._print_header("Stage 4: release drained pipe buffer")
        Session.pipe.print_info()
        Session.buf.print_info()
        return False


class SpliceToPipeBP(breakpoints.GenericContextBP):
    def _stop(self):
        self._print_header("Stage 5: splicing file to pipe")
        Session.pipe.print_info()
        Session.buf.print_info()
        Session.fmap.print_info()
        Session.page.print_info()
        return False


def main():
    # the name of the poc binary
    comm = "poc"

    OpenBP("fs/open.c:1220", comm=comm)
    PipeFcntlBP("fs/pipe.c:1401", comm=comm)
    PipeWriteBP("fs/pipe.c:597", comm=comm)
    PipeReadBP("fs/pipe.c:393", comm=comm)
    SpliceToPipeBP("fs/splice.c:1106", comm=comm)

    gdb.execute("c")


main()
