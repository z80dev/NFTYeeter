executor: public(address)
getModuleForKeycode: public(HashMap[bytes5, address])
getKeycodeForModule: public(HashMap[address, bytes5])
approvedPolicies: public(HashMap[address, bool])
_getWritePermissions: public(HashMap[bytes5, HashMap[address, bool]])
allPolicies: DynArray[address, 32] # what's a good max policies? dozens? hundreds?

interface Module:
    def KEYCODE() -> bytes5: view

interface Policy:
    def configureReads(): nonpayable
    def requestWrites() -> DynArray[bytes5, 32]: view

@external
def getWritePermissions(keycode: bytes5, policy: address) -> bool:
    return self._getWritePermissions[keycode][policy]

@external
def __init__():
    self.executor = msg.sender

@external
def installModule(newModule: address):
    assert msg.sender == self.executor
    keycode: bytes5 = Module(newModule).KEYCODE()
    assert self.getModuleForKeycode[keycode] == ZERO_ADDRESS
    self.getKeycodeForModule[newModule] = keycode
    self.getModuleForKeycode[keycode] = newModule

@external
def upgradeModule(newModule: address):
    assert msg.sender == self.executor
    keycode: bytes5 = Module(newModule).KEYCODE()
    oldModule: address = self.getModuleForKeycode[keycode]

    assert oldModule != ZERO_ADDRESS
    assert oldModule != newModule

    self.getKeycodeForModule[oldModule] = 0x0000000000
    self.getKeycodeForModule[newModule] = keycode
    self.getModuleForKeycode[keycode] = newModule

    for policy in self.allPolicies:
        if self.approvedPolicies[policy]:
            Policy(policy).configureReads()

@external
def approvePolicy(policy: address):
    assert msg.sender == self.executor
    assert self.approvedPolicies[policy] == False
    self.approvedPolicies[policy] = True
    Policy(policy).configureReads()
    permissions: DynArray[bytes5, 32] = Policy(policy).requestWrites()
    for permission in permissions:
        self._getWritePermissions[permission][policy] = True

@external
def terminatePolicy(policy: address):
    assert msg.sender == self.executor
    assert self.approvedPolicies[policy] == True
    self.approvedPolicies[policy] = False
    permissions: DynArray[bytes5, 32] = Policy(policy).requestWrites()
    for permission in permissions:
        self._getWritePermissions[permission][policy] = False
