// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {IntensiveColearnCheckin} from "../src/IntensiveColearnCheckin.sol";

/**
 * @title Deploy Script
 * @dev Script to deploy the IntensiveColearnCheckin contract
 */
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the IntensiveColearnCheckin contract
        IntensiveColearnCheckin checkinContract = new IntensiveColearnCheckin();
        
        vm.stopBroadcast();
        
        console.log("IntensiveColearnCheckin deployed at:", address(checkinContract));
        console.log("Deployer (owner):", vm.addr(deployerPrivateKey));
    }
}
