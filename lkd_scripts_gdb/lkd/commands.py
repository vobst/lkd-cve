import gdb

import os
import argparse

from lkd import memory
from lkd import structs

class PrintStructCMD(gdb.Command):
    '''
    Info: Generic way to make struct.print_info() available on the
          command line by creating an instance from supplied argument.
    '''
    def __init__(self, struct, prefix=False, command_name=None):
        '''
        @param              struct          The class of the struct we
                                            want to print.
        '''
        if command_name == None:
            command_name = "lkd_" + struct.__name__

        super().__init__(command_name, gdb.COMMAND_USER, gdb.COMPLETE_EXPRESSION, prefix)

        self.struct = struct

    def split_args(self, argument):
        '''
        Info: Split a command-line string from the user into arguments.
        '''
        return gdb.string_to_argv(argument)

    def invoke(self, argument, from_tty):
        argv = self.split_args(argument)
        argc = len(argv)
        if argc == 0 or argc > 2:
            self.print_usage()
        elif argc == 1:
            instance = self.instance_from_default(argv[0])
        else:
            instance = self.instance_from_alt("from_"+str(argv[0]), argv[1])
        instance.print_info()

    def instance_from_default(self, address):
        '''
        Info: Attempts to create the instance using the default
              constructor. Only addresses in hex are supported.
        '''
        return self.struct(int(address, 16))

    def instance_from_alt(self, alt, arg):
        '''
        Info: Attempt to create the instance using the alternative
              constructor specified by 'alt'.
        @param  String      alt     Name of the alternative constructor.
        '''
        return getattr(self.struct, alt)(int(arg, 16))


class SearchCMD(gdb.Command):
    def __init__(self, prefix=False):
        super().__init__("lkd_search" , gdb.COMMAND_USER, gdb.COMPLETE_EXPRESSION, prefix)
        self.init = False

    def lazy_init(self):
        with os.popen("pgrep qemu-system") as proc:
            pid = int(proc.read().strip(), 10)
        phys_mem = memory.VMPhysMem(pid)
        self.search_backend = memory.PhysMemSearcher(phys_mem=phys_mem)

        self.parser = argparse.ArgumentParser()
        self.parser.add_argument("area", choices=["all", "heap", "cache", "slab", "folio", "page-cache", "range"], help="Memory area to search.")


        pattern_group = self.parser.add_mutually_exclusive_group(required=True)
        pattern_group.add_argument("-s", "--string", type=lambda s: s.encode("ASCII"))
        pattern_group.add_argument("-b", "--bytes", type=lambda s: bytes.fromhex(s))

        self.parser.add_argument("-a", "--address", type=lambda s: int(s, 16), help="Virtual address (in hex) in search area.")

        self.init = True

    def invoke(self, argument, from_tty):
        if not self.init:
            self.lazy_init()

        argv = gdb.string_to_argv(argument)
        argv = self.parser.parse_args(argv)

        for pattern in {argv.string, argv.bytes}:
            if pattern:
                self.search_backend.pattern = pattern

        if argv.area in {"slab"}:
            getattr(self, "search_" + argv.area)(argv.address)
        else:
            raise NotImplementedError("TODO: Extend search command.")

        self.do_search()
        self.print_search_results()

    '''
    Info: Functions that initilize the ranges in the backend.
    '''
    def search_slab(self, address):
        slab = structs.Slab.from_virtual(address)
        start = structs.Page.page_to_phys(slab.address)
        length = structs.Page.pagesize * pow(2, slab.order)
        self.search_backend.ranges = [(start, length)]

    def do_search(self):
        self.search_backend.search()

    def print_search_results(self):
        for m in self.search_backend.matches:
            print(hex(structs.Page.phys_to_virt(m)))

SearchCMD()



            

