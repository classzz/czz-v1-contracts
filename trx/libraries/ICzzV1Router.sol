pragma solidity ^0.5.4;

interface ICzzV1Router {
    function getAddress() external returns(address ads); 
    // function getAmountsOut(IERC20 _srcToken, IERC20 _dstToken, uint256 _srcAmount)
    //     external view returns (uint256 dstAmount);
    function mint(address _srcToken, uint256 _srcAmount)
        external payable returns (uint256 dstAmount);
    function burn(address _srcToken, uint256 _srcAmount)
        external returns (uint256 dstAmount);
}
