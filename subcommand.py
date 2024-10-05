import argparse
import inspect

argp = argparse.ArgumentParser(
    prog = 'subcommand',
    description = 'a smart way to implement command line interfaces. '
)
subp = argp.add_subparsers(required=True)

def subcommand(description: str, positional: int = 0):
    """
    @param(description) description of a subcommand
    @param(positional) the number of positional arguments 
      (the first inputs of the decorated functions will become positional arguments)
    """
    def inner(f):
        """
        @param(f) this function becomes a subcommand
        """
        p = subp.add_parser(f.__name__.replace('_', '-'), help=description)
        for i, argspec in enumerate(inspect.getfullargspec(f).args):
            if i < positional:
                p.add_argument(argspec, action='store')
            else:
                p.add_argument(f"--{argspec.replace('_', '-')}", dest=argspec, action='store')
        p.set_defaults(func=f)
        return f
    return inner

@subcommand("copy input file to output file", positional = 2)
def copy(in_file, out_file, **kwargs):
    with open(in_file) as in_file:
        in_file = in_file.read()
    with open(out_file, 'w') as out_file:
        out_file.write(in_file)

if __name__ == '__main__':
    argv = argp.parse_args()
    argv.func(**argv.__dict__)
