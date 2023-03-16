// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TokenTimelockVault is AccessControlUpgradeable, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  struct Lock {
    address upstream;
    address beneficiary;
    uint releaseTime;
    uint amount;
  }

  bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  uint public totalLocked;

  mapping(bytes32 => Lock) private _locks;
  mapping(address => bool) public trustedUpstream;

  IERC20 private _token;

  event Locked(bytes32 indexed ref, address indexed upstream, address indexed beneficiary, uint releaseTime, uint amount);
  event Rollback(bytes32 indexed ref, address indexed upstream, address indexed beneficiary, uint releaseTime, uint amount, address by, string reason);
  event Released(bytes32 indexed ref, address indexed beneficiary, uint amount, uint when);

  function initialize(IERC20 token_) public initializer {
    __TokenTimelockVault_init(token_);
  }

  function __TokenTimelockVault_init(IERC20 token_) internal onlyInitializing {
    __TokenTimelockVault_init_unchained(token_);
  }

  function __TokenTimelockVault_init_unchained(IERC20 token_) internal onlyInitializing {
    _token = token_;
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _grantRole(ADMIN_ROLE, _msgSender());
    _grantRole(DEPLOYER_ROLE, _msgSender());
  }

  function token() public view returns (IERC20) {
    return _token;
  }

  function upstream(bytes32 ref) public view returns (address) {
    return _locks[ref].upstream;
  }

  function beneficiary(bytes32 ref) public view returns (address) {
    return _locks[ref].beneficiary;
  }

  function amount(bytes32 ref) public view returns (uint) {
    return _locks[ref].amount;
  }

  function releaseTime(bytes32 ref) public view returns (uint) {
    return _locks[ref].releaseTime;
  }

  function _exists(bytes32 ref) internal view returns (bool) {
    return upstream(ref) != address(0) && beneficiary(ref) != address(0) && releaseTime(ref) >= block.timestamp && amount(ref) > 0;
  }

  function lock(bytes32 ref, address upstream_, address beneficiary_, uint releaseTime_, uint amount_) public onlyRole(ADMIN_ROLE) {
    require(releaseTime_ > block.timestamp, "release time is before current time");
    require(ref == keccak256(abi.encodePacked(upstream_, beneficiary_, releaseTime_, amount_)), "ref mismatch");
    require(token().allowance(_msgSender(), address(this)) >= amount_, "insuffient fund to transfer");
    require(isTrustedUpstream(upstream_), "only trusted upstream");
    _locks[ref] = Lock({ upstream: upstream_, beneficiary: beneficiary_, releaseTime: releaseTime_, amount: amount_ });
    token().safeTransferFrom(_msgSender(), address(this), amount_);
    totalLocked += amount_;
    emit Locked(ref, upstream_, beneficiary_, releaseTime_, amount_);
  }

  function release(bytes32 ref) public {
    require(_exists(ref), "ref not exists");
    token().safeTransfer(beneficiary(ref), amount(ref));
    totalLocked -= amount(ref);
    emit Released(ref, beneficiary(ref), amount(ref), block.timestamp);
  }

  function rollback(bytes32 ref, string memory reason) public onlyRole(ADMIN_ROLE) {
    require(_exists(ref), "ref not exists");
    token().safeTransfer(upstream(ref), amount(ref));
    totalLocked -= amount(ref);
    emit Rollback(ref, upstream(ref), beneficiary(ref), releaseTime(ref), amount(ref), _msgSender(), reason);
  }

  function setTrustedUpstream(address upstream_, bool trusted) public onlyRole(ADMIN_ROLE) {
    trustedUpstream[upstream_] = trusted;
  }

  function isTrustedUpstream(address upstream_) public view returns (bool) {
    return trustedUpstream[upstream_];
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEPLOYER_ROLE) {}

  uint256[50] private __gap;
}
