import gdb


class GenericStruct:
    """
    Info: Container for a struct. Do not instantiate directly.
    @attr   gdb.Value   address     pointer to struct
    @cvar   gdb.Value   stype       structure type
    @cvar   gdb.Value   ptype       structure pointer type
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
        @param  String      member      struct member to get
        """
        return self.address.dereference()[member]

    def print_member(self, member):
        """
        @param  String      member      struct member to print
        """
        value = self.get_member(member)
        if value.type.code == gdb.TYPE_CODE_PTR and int(value) == 0:
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
    stype = gdb.lookup_type("struct task_struct")
    ptype = stype.pointer()

    def _print_info(self):
        self.print_member("pid")
        self.print_member("comm")


class Pipe(GenericStruct):
    stype = gdb.lookup_type("struct pipe_inode_info")
    ptype = stype.pointer()

    def _print_info(self):
        self.print_member("head")
        self.print_member("tail")
        self.print_member("ring_size")
        self.print_member("bufs")


class PipeBuffer(GenericStruct):
    stype = gdb.lookup_type("struct pipe_buffer")
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
        if len(tmp) == 0:
            return "none"
        return " | ".join(tmp)

    def _print_info(self):
        # TODO add print_misc to parent
        self.print_member("page")
        self.print_member("offset")
        self.print_member("len")
        self.print_member("ops")
        print("> 'flags': " + self.sym_flags())


class File(GenericStruct):
    stype = gdb.lookup_type("struct file")
    ptype = stype.pointer()

    def get_filename(self):
        # TODO Maybe make it like page_address so it can be used as
        #   a convenience function without creating class instance
        return self.get_member("f_path")["dentry"]["d_name"]["name"].string()

    def _print_info(self):
        # TODO add print_misc to parent
        self.print_member("f_mapping")
        print("> filename: " + self.get_filename())


class AddrSpace(GenericStruct):
    stype = gdb.lookup_type("struct address_space")
    ptype = stype.pointer()

    def _print_info(self):
        # TODO add print_misc to parent
        self.print_member('a_ops')
        print("> 'i_pages.xa_head' : {0}".format(self.get_member("i_pages")["xa_head"]))


class XArray(GenericStruct):
    stype = gdb.lookup_type("struct xarray")
    ptype = stype.pointer()
    # TODO implement proper xarray functionality
    def _print_info(self):
        pass


class Page(GenericStruct):
    stype = gdb.lookup_type("struct page")
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

        vmemmap_base = int(gdb.parse_and_eval("vmemmap_base"))
        page_offset_base = int(gdb.parse_and_eval("page_offset_base"))
        page = int(page)
        return (
            int((page - vmemmap_base) / Page.stype.sizeof) << Page.page_shift
        ) + page_offset_base

    def _print_info(self):
        # TODO add print_misc to parent
        print("> virtual: " + hex(self.virtual))
        print(
            "> data: "
            + str(gdb.selected_inferior().read_memory(self.virtual, 20).tobytes())
            + "[...]"
            + str(
                gdb.selected_inferior()
                .read_memory(self.virtual + self.pagesize - 20, 20)
                .tobytes()
            )
        )


