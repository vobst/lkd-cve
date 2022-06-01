'''
Design decisions:
    - interact with kernel gdb scripts via gdb.parse_and_eval

TODO
> add gdb cli functions
    lkd_page_address
    lkd_page_data
    lkd_file_name
    lkd_file_path
'''


import os

sys.path.insert(0, os.path.dirname(__file__) + "/lkd_scripts_gdb")

try:
    gdb.parse_and_eval("0")
    gdb.execute("", to_string=True)
except:
    gdb.write("NOTE: gdb 7.2 or later required for Linux helper scripts to "
              "work.\n")
else:
    import lkd.session
    import lkd.structs
    import lkd.breakpoints
