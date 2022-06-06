import gdb

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


