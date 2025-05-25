// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "../../interfaces/core/IDenManager.sol";
import "../../interfaces/core/IFactory.sol";

/*  Helper contract for grabbing Den data for the front end. Not part of the core Beraborrow system. */
contract DenManagerGetters {
    struct Collateral {
        address collateral;
        address[] denManagers;
    }

    IFactory public immutable factory;

    constructor(IFactory _factory) {
        factory = _factory;
    }

    /**
        @notice Returns all active system den managers and collaterals, as an
        `       array of tuples of [(collateral, [denManager, ...]), ...]
     */
    function getAllCollateralsAndDenManagers() external view returns (Collateral[] memory) {
        uint256 length = factory.denManagerCount();
        address[2][] memory denManagersAndCollaterals = new address[2][](length);
        address[] memory uniqueCollaterals = new address[](length);
        uint256 collateralCount;
        for (uint i; i < length; i++) {
            address denManager = factory.denManagers(i);
            address collateral = address(IDenManager(denManager).collateralToken());
            denManagersAndCollaterals[i] = [denManager, collateral];
            for (uint x; x < length; x++) {
                if (uniqueCollaterals[x] == collateral) break;
                if (uniqueCollaterals[x] == address(0)) {
                    uniqueCollaterals[x] = collateral;
                    collateralCount++;
                    break;
                }
            }
        }
        Collateral[] memory collateralMap = new Collateral[](collateralCount);
        for (uint i; i < collateralCount; i++) {
            collateralMap[i].collateral = uniqueCollaterals[i];
            uint dmCollCount = 0;
            address[] memory denManagers = new address[](length);
            for (uint x; x < length; x++) {
                if (denManagersAndCollaterals[x][1] == uniqueCollaterals[i]) {
                    denManagers[dmCollCount] = denManagersAndCollaterals[x][0];
                    ++dmCollCount;
                }
            }
            collateralMap[i].denManagers = new address[](dmCollCount);
            for (uint x = 0; x < dmCollCount; x++) {
                collateralMap[i].denManagers[x] = denManagers[x];
            }
        }

        return collateralMap;
    }

    /**
        @notice Returns a list of den managers where `account` has an existing den
     */
    function getActiveDenManagersForAccount(address account) external view returns (address[] memory) {
        uint256 length = factory.denManagerCount();
        address[] memory denManagers = new address[](length);
        uint256 dmCount;
        for (uint i; i < length; i++) {
            address denManager = factory.denManagers(i);
            if (IDenManager(denManager).getDenStatus(account) > 0) {
                denManagers[dmCount] = denManager;
                ++dmCount;
            }
        }
        assembly {
            mstore(denManagers, dmCount)
        }
        return denManagers;
    }
}
