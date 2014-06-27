## What is it? ##

create-ram-disk is a tiny little Mac command-line tool that creates, formats and
mounts a RAM disk of the given name and size. It wraps the built-in tools
`hdiutil` and `diskutil` in a slightly more friendly manner, and does cleanup
if the commands fail for some reason.

## License ##

create-ram-disk is licensed under three-clause BSD. The license document can be
found [here](https://github.com/iKenndac/create-ram-disk/blob/master/LICENSE.markdown).

## Building ##

1. Clone create-ram-disk using `$ git clone git://github.com/iKenndac/create-ram-disk.git`.
2. Open the project and build away!

## Usage ##

`$ create-ram-disk -name <RAM disk name> -size <size>`

  * `-name` The name of the RAM disk. Will be used as the mount point and the
    volume's label.

  * `-size` The size of the RAM disk. Value must be a nonzero integer followed
    by `MB` or `GB`, such as `500MB` or `2GB`.
