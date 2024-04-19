// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.1/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {LibDomainPrice} from '../libraries/LibDomainPrice.sol';
import {IMainDiamond} from "../interfaces/IMainDiamond.sol";

contract DomainPriceFacet {

    using SafeMath for uint256;

    modifier onlyOwner() {
        require(IMainDiamond(payable(address(this))).owner() == msg.sender, "Only the owner can call this");
        _;
    }

    function initializeDomainPrice(address aggregatorAddress_) external onlyOwner {
       LibDomainPrice.DomainPriceDiamondStorage storage dp = LibDomainPrice.diamondStorage();
       require(!dp.initialized, "DomainPriceFacet: Contract instance has already been initialized");
       dp._fiveLetter = 35;
       dp._fourLetter = 95;
       dp._threeLetter = 145;
       dp._threeYearsDiscount = 10;
       dp._fiveYearsDiscount = 30;
       dp._tenYearsDiscount = 50;
       dp._tolerance = 98;
       dp._aggregatorAdress = AggregatorV3Interface(aggregatorAddress_);
       dp.initialized = true;
    }

    function setAggregatorAddress(address aggregatorAddress_) external onlyOwner {
        LibDomainPrice.DomainPriceDiamondStorage storage dp = LibDomainPrice.diamondStorage();
        dp._aggregatorAdress = AggregatorV3Interface(aggregatorAddress_);
    }

    function getCurrency() public view returns (uint256) {
        LibDomainPrice.DomainPriceDiamondStorage storage dp = LibDomainPrice.diamondStorage();
    // prettier-ignore
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dp._aggregatorAdress.latestRoundData();
        return uint256(price*10**10);
    }

    function changePrice(uint256 threeLetter_ , uint256 fourLetter_, uint256 fiveLetter_) external onlyOwner{
        LibDomainPrice.changePrice(threeLetter_, fourLetter_, fiveLetter_);
    }

    function changeDiscount(uint256 threeYears_, uint256 fiveYears_, uint256 tenYears_) external onlyOwner{
        LibDomainPrice.changeDiscount(threeYears_, fiveYears_, tenYears_);
    }

    function changeTolerance(uint256 tolerance_) external onlyOwner{
        LibDomainPrice.changeTolerance(tolerance_);
    }

    function getTolerance() public view returns (uint256){
        return LibDomainPrice.getTolerance();
    }

    function getDomainDiscount(uint256 year_) internal view returns(uint256){
        return LibDomainPrice.getDomainDiscount(year_);
    }

    function getDomainPrice(string calldata domainName_, uint256 year_) external view returns (uint256) {
        LibDomainPrice.DomainPriceDiamondStorage storage dp = LibDomainPrice.diamondStorage();
        uint256 lenCount = bytes(domainName_).length;
        uint256 domainDiscountValue = getDomainDiscount(year_);
        uint256 domainPriceValue = 0;
        if (lenCount <= 3) {
            domainPriceValue = dp._threeLetter;
        } else if (lenCount == 4) {
            domainPriceValue = dp._fourLetter;
        } else if (lenCount >= 5) {
            domainPriceValue = dp._fiveLetter;
        }
        uint256 priceInUSD = domainPriceValue.mul(10**36).mul(year_).sub(domainPriceValue.mul(10**36).mul(domainDiscountValue).div(100));
        uint256 priceInWei = priceInUSD.div(getCurrency()); 
        return priceInWei;
    }
}