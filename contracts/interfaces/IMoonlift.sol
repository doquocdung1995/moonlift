// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IMoonlift {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @notice Creates `_amount` token to `_to`.
     */
    function mint(address _to, uint256 _amount) external;
}
