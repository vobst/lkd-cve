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
        @param  undef       address     pointer to struct
        """
        try:
            address.type
        except:
            address = gdb.Value(address)

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

    # TODO move to parent
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


class Slab(GenericStruct):
    try:
        stype = gdb.lookup_type("struct slab")
    except:
        # Problem: Pre 5.17 kernels have no 'struct slab' and handle it 
        #   as a 'stuct page' union member instead.
        #   https://lwn.net/Articles/881039/
        stype = gdb.lookup_type("struct page")
    ptype = stype.pointer()

    @classmethod
    def from_folio(cls, folio):
        '''
        Info: Converts a Folio to Slab.
        @param  Folio       folio       Folio we want to convert to Slab.
        '''
        return cls(folio.address)

    @classmethod
    def from_page(cls, page):
        '''
        Info: Constructs a Slab from any Page within it.
        @param  Page        page        Page we want to know Slab of.
        '''
        folio = Folio.from_page(page)
        return cls.from_folio(folio)

    @classmethod
    def from_virtual(cls, virtual):
        '''
        Info: Constructs a Slab from any virtual address within it.
        @param              virtual     Any virtual address within slab. 
                                        E.g. whats returned by kmalloc.
        '''
        page = Page.from_virtual(virtual)
        return cls.from_page(page)

    def _print_info(self):
        host = KmemCache(self.get_member('slab_cache'))
        folio = Folio.from_slab(self)
        self.print_member('freelist')
        folio._print_info()
        host._print_info()


class Page(GenericStruct):
    stype = gdb.lookup_type("struct page")
    ptype = stype.pointer()
    pagesize = 4096
    page_shift = 12
    vmemmap_base = int(gdb.parse_and_eval("vmemmap_base"))
    page_offset_base = int(gdb.parse_and_eval("page_offset_base"))
    flags = {'PG_HEAD': (1<<16)}

    def __init__(self, address):
        """
        @attr   gdb.Value   virtual     virtual address of data
        """
        super().__init__(address)
        self.virtual = self.page_address(self.address)

    @classmethod
    def from_virtual(cls, virtual):
        '''
        Info: Constructs a Page from any  virtual address within it.
        '''
        pfn = (int(virtual) - cls.page_offset_base) >> cls.page_shift
        return cls(cls.vmemmap_base + int(cls.stype.sizeof) * pfn)

    @classmethod
    def page_address(cls, page):
        """
        Info: Calculates the virtual address of a page
        @param  undefined   page        'struct page *'
        """
        page = int(page)
        return (
            int((page - cls.vmemmap_base) / cls.stype.sizeof) << cls.page_shift
        ) + cls.page_offset_base

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


class Folio(GenericStruct):
    # TODO list with pages of folio
    try:
        stype = gdb.lookup_type("struct folio")
    except:
        # Problem: Pre 5.14 kernels have no folios. They use compound
        #   pages instead. https://lwn.net/Articles/849538/
        stype = gdb.lookup_type("struct page")
    ptype = stype.pointer()
    flags = Page.flags

    @classmethod
    def from_slab(cls, slab):
        '''
        Info: Converts Slab to Folio.
        @param  Slab        slab        Slab we want to convert to folio.
        '''
        return cls(slab.address)

    @classmethod
    def from_page(cls, page):
        '''
        Info: Constuct Folio from any Page within it.
        @param  Page        page        Page instance we want to get the 
                                        folio of.
        '''
        head = int(page.get_member('compound_head'))
        if  head & 1:
            return cls(head - 1)
        else:
            return cls(page.address)

    @classmethod
    def from_virtual(cls, virtual):
        '''
        Info: Constructs a folio from any virtual address within it.
        '''
        page = Page.from_virtual(virtual)
        return cls.from_page(page)

    @property
    def order(self):
        '''
        Info: A folio contains 2^order pages. This info is stored on the
              first tail page.
        '''
        if int(self.get_member('flags')) & self.flags.get('PG_HEAD'):
            return int(self.address[1].cast(Page.stype)['compound_order'])
        else:
            return 0

    def _print_info(self):
        print("> 'order': " + hex(self.order))


class KmemCache(GenericStruct):
    stype = gdb.lookup_type('struct kmem_cache')
    ptype = stype.pointer()
    list_offset = [f.bitpos // 8 for f in stype.fields() if f.name == "list"][0]
    flags = None

    @classmethod
    def from_list(cls, lst):
        '''
        Info: Constructor from &cache->list
        '''
        return cls(int(lst) - cls.list_offset)

    def nxt(self):
        pass

    def prev(self):
        pass

    def _print_info(self):
        self.print_member('name')
        self.print_member('size')
        self.print_member('object_size')


