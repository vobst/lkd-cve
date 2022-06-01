"""
# TODO 
> add gdb cli functions
lkd_page_address
lkd_page_data
lkd_file_name
lkd_file_path
"""

import gdb as g


class Session():
    '''
    Info: Container to store information during a debugging session.
    '''
    task = None
    pipe = None
    buf = None
    file = None
    fmap = None
    page = None

    def __init__(self):
        pass


class GenericStruct:
    """
    Info: Container for a struct. Do not instantiate directly.
    @attr   gdb.Value   address     pointer to struct
    """

    stype = None
    ptype = None

    def __init__(self, address):
        """
        @param  gdb.Value   address     pointer to struct
        """
        if str(address.type) != str(self.ptype):
            address = address.cast(self.ptype)
        self.address = address

    def get_member(self, member):
        """
        @param String member: struct member to get
        """
        return self.address.dereference()[member]

    def print_member(self, member):
        """
        @param String member: struct member to print
        """
        value = self.get_member(member)
        if value.type.code == g.TYPE_CODE_PTR and int(value) == 0:
            value = 'NULL'
        print("> '{0}': {1}".format(member, value))

    def print_header(self):
        """
        Info: prints type and address of the struct.
        """
        # TODO use classvarible type
        print("{0} at {1}".format(self.address.dereference().type, self.address))

    def print_info(self):
        """
        Info: Prints summary including 'interesting' members of the
        struct.
        """
        self.print_header()
        self._print_info()
        print("")

    def _print_info(self):
        """
        Implement yourself when subclassing.
        """
        pass


class Task(GenericStruct):
    stype = g.lookup_type("struct task_struct")
    ptype = stype.pointer()

    def _print_info(self):
        self.print_member("pid")
        self.print_member("comm")


class Pipe(GenericStruct):
    stype = g.lookup_type("struct pipe_inode_info")
    ptype = stype.pointer()

    def _print_info(self):
        self.print_member("head")
        self.print_member("tail")
        self.print_member("ring_size")
        self.print_member("bufs")


class PipeBuffer(GenericStruct):
    stype = g.lookup_type("struct pipe_buffer")
    ptype = stype.pointer()
    flags = {
        "PIPE_BUF_FLAG_LRU": 0x01,
        "PIPE_BUF_FLAG_ATOMIC": 0x02,
        "PIPE_BUF_FLAG_GIFT": 0x04,
        "PIPE_BUF_FLAG_PACKET": 0x08,
        "PIPE_BUF_FLAG_CAN_MERGE": 0x10,
        "PIPE_BUF_FLAG_WHOLE": 0x20,
    }

    def sym_flags(self):
        tmp = []
        for key, value in self.flags.items():
            if int(self.get_member("flags")) & value != 0:
                tmp.append(key)
        return " | ".join(tmp)

    def _print_info(self):
        self.print_member("page")
        self.print_member("offset")
        self.print_member("len")
        self.print_member("ops")
        print("> 'flags': " + self.sym_flags())


class File(GenericStruct):
    stype = g.lookup_type("struct file")
    ptype = stype.pointer()

    def get_filename(self):
        # TODO Maybe make it like page_address so it can be used as
        #   a convenience function without creating class instance
        return self.get_member("f_path")["dentry"]["d_name"]["name"].string()

    def _print_info(self):
        self.print_member("f_mapping")
        print("> filename: " + self.get_filename())


class AddrSpace(GenericStruct):
    stype = g.lookup_type("struct address_space")
    ptype = stype.pointer()

    def _print_info(self):
        self.print_member('a_ops')
        print("> 'i_pages.xa_head' : {0}".format(self.get_member("i_pages")["xa_head"]))


class XArray(GenericStruct):
    stype = g.lookup_type("struct xarray")
    ptype = stype.pointer()
    # TODO implement proper xarray functionality
    def _print_info(self):
        pass


class Page(GenericStruct):
    stype = g.lookup_type("struct page")
    ptype = stype.pointer()
    pagesize = 4096
    page_shift = 12

    def __init__(self, address):
        """
        @attr   gdb.Value   virtual     virtual address of cached data
        """
        super().__init__(address)
        self.virtual = self.page_address(self.address)

    @staticmethod
    def page_address(page):
        """
        Info: Calculates the virtual address of a page
        @param  gdb.Value   page        'struct page *'
        """

        vmemmap_base = int(g.parse_and_eval("vmemmap_base"))
        page_offset_base = int(g.parse_and_eval("page_offset_base"))
        page = int(page)
        return (
            int((page - vmemmap_base) / Page.stype.sizeof) << Page.page_shift
        ) + page_offset_base

    def _print_info(self):
        print("> virtual: " + hex(self.virtual))
        print(
            "> data: "
            + str(g.selected_inferior().read_memory(self.virtual, 20).tobytes())
            + "[...]"
            + str(
                g.selected_inferior()
                .read_memory(self.virtual + self.pagesize - 20, 20)
                .tobytes()
            )
        )


class GenericContextBP(g.Breakpoint):
    """
    Info: A Breakpoint that is only active in a given context.
    """

    def __init__(self, *args, **kwargs):
        """
        @attr   String      comm        'comm' member of 'struct
                                        task_struct' of process in whose
                                        context we want to stop
        """
        super().__init__(*args)
        self._comm = kwargs["comm"]
        self._condition = f"""$_streq($lx_current().comm, "{self._comm}")"""

    def _condition_holds(self):
        return bool(g.parse_and_eval(self._condition))

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


class OpenBP(GenericContextBP):
    def _stop(self):
        Session.file = File(g.parse_and_eval("f"))
        if Session.file.get_filename() != "target_file":
            return False
        Session.task = Task(g.parse_and_eval("$lx_current()").address)
        Session.fmap = AddrSpace(Session.file.get_member("f_mapping"))
        Session.page = Page(Session.fmap.get_member("i_pages")["xa_head"])
        self._print_header("Stage 1: open the target file")
        Session.task.print_info()
        Session.file.print_info()
        Session.fmap.print_info()
        Session.page.print_info()
        return False


class PipeFcntlBP(GenericContextBP):
    def _stop(self):
        Session.pipe = Pipe(g.parse_and_eval("file")["private_data"])
        Session.buf = PipeBuffer(Session.pipe.get_member("bufs"))
        self._print_header("Stage 2: create pipe")
        Session.pipe.print_info()
        Session.buf.print_info()
        return False


class PipeWriteBP(GenericContextBP):
    def _stop(self):
        if int(Session.buf.get_member("len")) not in {8, 18, 4096}:
            return False
        else:
            buf_page = Page(Session.buf.get_member("page"))
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


class PipeReadBP(GenericContextBP):
    def _stop(self):
        if int(Session.buf.get_member("len")) != 0:
            return False
        self._print_header("Stage 4: release drained pipe buffer")
        Session.pipe.print_info()
        Session.buf.print_info()
        return False


class SpliceToPipeBP(GenericContextBP):
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

    g.execute("c")


main()
