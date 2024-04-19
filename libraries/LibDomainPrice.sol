// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library LibDomainPrice {
    struct DomainPriceDiamondStorage {
        bool initialized;
        uint256 _fiveLetter;
        uint256 _fourLetter;
        uint256 _threeLetter;
        uint256 _threeYearsDiscount;
        uint256 _fiveYearsDiscount;
        uint256 _tenYearsDiscount;
        uint256 _tolerance;
        AggregatorV3Interface _aggregatorAdress;
    }

    function diamondStorage() internal pure returns (DomainPriceDiamondStorage storage dp) {
        bytes32 storagePosition = keccak256("domainPrice.storage");
        assembly {
            dp.slot := storagePosition
        }
    }

    function changePrice(uint256 threeLetter_ , uint256 fourLetter_, uint256 fiveLetter_) internal {
        LibDomainPrice.DomainPriceDiamondStorage storage dp = LibDomainPrice.diamondStorage();
        if (threeLetter_  != 0){
            dp._threeLetter = threeLetter_ ;
        }
        if (fourLetter_ != 0){
            dp._fourLetter = fourLetter_;
        }
        if (fiveLetter_ != 0){
            dp._fiveLetter = fiveLetter_;
        }
    }

    function changeDiscount(uint256 threeYears_, uint256 fiveYears_, uint256 tenYears_) internal {
        LibDomainPrice.DomainPriceDiamondStorage storage dp = LibDomainPrice.diamondStorage();
        if (threeYears_ != 0){
            dp._threeYearsDiscount = threeYears_;
        }
        if (fiveYears_ != 0){
            dp._fiveYearsDiscount = fiveYears_;
        }
        if (tenYears_ != 0){
            dp._tenYearsDiscount = tenYears_;
        }
    }

    function changeTolerance(uint256 tolerance_) internal {
        LibDomainPrice.DomainPriceDiamondStorage storage dp = LibDomainPrice.diamondStorage();
        dp._tolerance = tolerance_;
    }

    function getTolerance() internal view returns (uint256) {
        LibDomainPrice.DomainPriceDiamondStorage storage dp = LibDomainPrice.diamondStorage();
        return dp._tolerance;
    }

    function getDomainDiscount(uint256 year_) internal view returns(uint256){
        LibDomainPrice.DomainPriceDiamondStorage storage dp = LibDomainPrice.diamondStorage();
        if (year_ == 3){
            return dp._threeYearsDiscount;
        }
        else if(year_ == 5){
            return  dp._fiveYearsDiscount;
        }
        else if(year_ == 10){
            return dp._tenYearsDiscount;
        }
        return 0;
    }

}