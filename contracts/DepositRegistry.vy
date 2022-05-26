import Kernel as Kernel

kernel: public(address)
KEYCODE: public(bytes5)

@external
def __init__(kernel: address):
    self.kernel = kernel
    # self.KEYCODE = convert(b"DPREG", bytes5)
    self.KEYCODE = 0x0000000000

@internal
def _isPermitted():
    assert Kernel(self.kernel).getWritePermissions(self.KEYCODE, msg.sender)
