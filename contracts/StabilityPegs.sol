// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DOLA is ERC20, Ownable {
    ERC20 public bdolaToken;
    ERC20 public roiToken;
    uint256 public collateralizationRatio = 1 ether; // Initial 1:1 collateral ratio
    uint256 public stabilityFee = 0.005 ether; // Stability fee for minting/burning

    constructor(address _bdolaAddress, address _roiAddress) ERC20("DOLA", "DOLA") Ownable(msg.sender) {
        bdolaToken = ERC20(_bdolaAddress);
        roiToken = ERC20(_roiAddress);
    }

    // Function to mint DOLA based on the ROI peg and BDOLA collateral
    function mintDOLA(uint256 bdolaAmount) external {
        require(bdolaAmount > 0, "Must provide BDOLA collateral");

        uint256 dolaToMint = calculateDOLA(bdolaAmount);
        require(roiToken.balanceOf(address(this)) >= dolaToMint, "Insufficient ROI backing");

        require(bdolaToken.allowance(msg.sender, address(this)) >= bdolaAmount, "Insufficient allowance to spend");

        require(bdolaToken.transferFrom(msg.sender, address(this), bdolaAmount), "Collateral transfer failed");
        _mint(msg.sender, dolaToMint);
    }

    // Function to redeem DOLA for BDOLA based on ROI peg
    function redeemDOLA(uint256 dolaAmount) external {
        require(dolaAmount > 0, "Must specify DOLA to burn");
        require(balanceOf(msg.sender) >= dolaAmount, "Insufficient DOLA balance");

        uint256 bdolaToReturn = calculateBDOLA(dolaAmount);
        require(bdolaToken.balanceOf(address(this)) >= bdolaToReturn, "Insufficient BDOLA in contract");

        _burn(msg.sender, dolaAmount);
        require(bdolaToken.transfer(msg.sender, bdolaToReturn), "Collateral return failed");
    }

    // Internal function to calculate DOLA minted based on collateral and ROI peg
    function calculateDOLA(uint256 bdolaAmount) internal view returns (uint256) {
        uint256 dolaAmount = (bdolaAmount * collateralizationRatio) / 1 ether;
        
        // Applying stability fee
        uint256 adjustedAmount = dolaAmount - ((dolaAmount * stabilityFee) / 1 ether);
        
        // Adjust based on ROI supply to reflect peg
        uint256 roiSupply = roiToken.totalSupply();
        uint256 dolaSupply = totalSupply();
        
        if (dolaSupply > roiSupply) {
            adjustedAmount = adjustedAmount * roiSupply / dolaSupply; // Adjust down if oversupplied
        }

        return adjustedAmount;
    }

    // Internal function to calculate BDOLA collateral return when burning DOLA
    function calculateBDOLA(uint256 dolaAmount) internal view returns (uint256) {
        uint256 bdolaAmount = (dolaAmount * 1 ether) / collateralizationRatio;
        
        // Adjust based on ROI supply to stabilize the peg
        uint256 roiSupply = roiToken.totalSupply();
        uint256 dolaSupply = totalSupply();

        if (dolaSupply < roiSupply) {
            bdolaAmount = bdolaAmount * roiSupply / dolaSupply; // Adjust up if undersupplied
        }

        return bdolaAmount;
    }

    // Admin function to adjust stability fee and collateralization ratio
    function adjustParameters(uint256 newCollateralRatio, uint256 newStabilityFee) external onlyOwner {
        require(newCollateralRatio >= 1 ether, "Collateralization ratio must be >= 1");
        require(newStabilityFee <= 0.05 ether, "Fee too high");
        collateralizationRatio = newCollateralRatio;
        stabilityFee = newStabilityFee;
    }
}
