===========
Linux
===========
> sudo apt-get install libssl-dev
> sudo apt-get install python3-pip
> sudo apt-get install python3-cffi

===========
Compilation
===========
> python3 -m pip install --upgrade pip
> python3 -m pip install --upgrade setuptools
> python3 -m pip install cffi==1.3.1    # This step may not be needed if installed above
> python3 -m pip install wheel
> python3 setup.py bdist_wheel

A distribution wheel (*.whl) will be created in /dist folder

============
Installation
============
User can install the python program using pip by:
> cd dist
> python3 -m pip install cryptotvgen-{<package_version>}-py3-none-any.whl


============
Usage
============

See help
> python3 -m cryptotvgen -h

============
Example
============

See examples/ for more details
