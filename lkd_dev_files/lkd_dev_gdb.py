import os

sys.path.insert(0, "/"+os.environ['PROJECTE']+"/lkd_scripts_gdb")

from lkd import session
from lkd import structs
from lkd import breakpoints


class Session(session.GenericSession):
    task = None
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




def main():
    # the name of the poc binary
    comm = "poc"

    OpenBP("fs/open.c:1220", comm=comm)

    gdb.execute("c")


main()
