import gdb

import os


class VMPhysMem:
    """
    Source: This class was adapted from
            https://github.com/martinradev/gdb-pt-dump
    Info: Gets a handle to virtual memory of host QEMU process and uses
          guest-physical to host-virtual translation for quick scanning
          of the guests memory.
    """

    def __init__(self, pid):
        """
        @param  Int         pid         PID of QEMU process on the host.
        """
        self.pid = pid
        self.file = os.open(f"/proc/{pid}/mem", os.O_RDONLY)
        self.mem_size = os.fstat(self.file).st_size

    def __close__(self):
        if self.file:
            os.close(self.file)

    def read(self, phys_addr, length):
        """
        @param  Int         phys_addr       The guest physical address to
                                            start reading from.
        @param  Int         length          How much to read.
        @return Bytes       data            The data read.
        """
        # TODO check if this can be done nicer
        res = gdb.execute(f"monitor gpa2hva {hex(phys_addr)}", to_string=True)

        # Problem: It's not possible to pread large sizes, so let's
        #          break the request into a few smaller ones.
        max_block_size = 1024 * 1024 * 256
        try:
            hva = int(res.split(" ")[-1], 16)
            data = b""
            for offset in range(0, length, max_block_size):
                length_to_read = min(length - offset, max_block_size)
                block = os.pread(self.file, length_to_read, hva + offset)
                data += block
            return data
        except Exception as e:
            msg = f"Physical address ({hex(phys_addr)}, +{hex(length)}) is not accessible. Reason: {e}. gpa2hva result: {res}"
            raise OSError(msg)


class PhysMemSearcher():
    '''
    @attr   List        matches         List of guest physical addresses
                                        where a match was found.
    '''
    def __init__(self, ranges=None, pattern=None, phys_mem=None)
        '''
        @param  List        ranges          List of touples (address, len)
                                            that defines the search area.
        @param  Bytes       pattern         The byte pattern to search.
        @param  VMPhysMem   phys_mem        The guests physical memory.
        '''
        if ranges:
            self.ranges = ranges
        if pattern:
            self.pattern = pattern
        if phys_mem:
            self.phys_mem = phys_mem
        self.matches = []

    def search(self):
        '''
        Info: Does the search. Saves results in self.matches.
        '''
        for rg in self.ranges:
            start, length = rg
            data = self.phys_mem.read(start, length)
            self.matches.extend(self.search_data(start, data))

    def search_data(self, start, data):
        '''
        Info: Finds all occurances of pattern in data.
        @param  Int         start           Base address of data.
        @param  Bytes       data            The data to search.
        @return List        ret             Guest physical addresses where
                                            a match was found.
        '''
        ret = []
        offset = 0
        while True:
            idx = data[offset::].find(self.pattern)
            if idx == -1:
                break
            ret.append(start + offset + idx)
            offset += idx + len(self.pattern)
        return ret

