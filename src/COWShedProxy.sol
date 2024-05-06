import { COWShedStorage, IMPLEMENTATION_STORAGE_SLOT } from "./COWShedStorage.sol";
import { COWShed, Call } from "./COWShed.sol";
import { Proxy } from "openzeppelin-contracts/contracts/proxy/Proxy.sol";

contract COWShedProxy is COWShedStorage, Proxy {
    error InvalidInitialization();

    event Upgraded(address indexed implementation);

    address internal immutable ADMIN;

    constructor(address implementation, address admin_) {
        ADMIN = admin_;
        assembly {
            sstore(IMPLEMENTATION_STORAGE_SLOT, implementation)
        }
    }

    function updateImplementation(address newImplementation) external {
        if (msg.sender == ADMIN) {
            assembly {
                sstore(IMPLEMENTATION_STORAGE_SLOT, newImplementation)
            }
            emit Upgraded(newImplementation);
        }
        // transparent proxy for everyone other than admin
        else {
            _fallback();
        }
    }

    function admin() external returns (address) {
        if (msg.sender == address(this)) {
            return ADMIN;
        }
        // transparently proxy for everyone other than self. this will allow the implementation
        // to get the admin of the proxy without using the storage, and it costs the same
        // if not less than using admin storage variable
        else {
            _fallback();
        }
    }

    fallback() external payable override {
        if (!_state().initialized && msg.sig != COWShed.initialize.selector) revert InvalidInitialization();
        _fallback();
    }

    receive() external payable { }

    function _implementation() internal view override returns (address implementation) {
        assembly {
            implementation := sload(IMPLEMENTATION_STORAGE_SLOT)
        }
    }
}
