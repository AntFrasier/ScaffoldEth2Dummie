//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Use openzeppelin to inherit battle-tested implementations (ERC20, ERC721, etc)
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LoyaltEthCards.sol";

/**
 * A smart contract that allows changing a state variable of the contract and tracking the changes
 * It also allows the owner to withdraw the Ether in the contract
 * @author Cyril Maranber
 */
contract PartnerVendorContract is Ownable {

	address payable nftrAddress;
	mapping (uint256 => uint256) private balanceOfNftId; // store the balance of each nft used
	LoyaltEthCards public LOYALTETHCONTRACT;

	constructor (address _nftAddress) {
		nftrAddress = payable(_nftAddress);
		LOYALTETHCONTRACT = LoyaltEthCards(nftrAddress); //should have a payable address to receive the funds instead of owner because the receiver could be a smart contrat an d not a eoa ??
	}

	function receivePayement(uint256 _myTokenId) external payable { //the amount that is sent should be handle front end 
		require (msg.value > 0, "no money sent");
		require (LOYALTETHCONTRACT.ownerOf(_myTokenId) == msg.sender, "Not the owner of that NFT"); //this is not realy usefull .... an other one can buy soething and put on the card of someone else ?
		require (LOYALTETHCONTRACT.getTokenUsedById(_myTokenId) < LOYALTETHCONTRACT.getTokenRequired(_myTokenId), "Your card is full");
		require (LOYALTETHCONTRACT.getTokenDeadLine(_myTokenId) >= block.timestamp, "your card is expired");
		uint256 reward = (msg.value * LOYALTETHCONTRACT.getTokenPercent(_myTokenId)) / 100;
		(bool success, ) = owner().call{value: msg.value - reward}(""); //instead of owner it has to be the receiver address... .??
		require (success, "tranfert failed");
		balanceOfNftId[_myTokenId] += reward;
		LOYALTETHCONTRACT.incTokenIdUsed(_myTokenId);
	}

	function withdraw(uint256 _myTokenId) external {
		require ((msg.sender == owner()) || (msg.sender == LOYALTETHCONTRACT.ownerOf(_myTokenId)), "should be the owner or own an NFT");
		require(balanceOfNftId[_myTokenId] > 0, "no money to withdraw");
		if (msg.sender == owner()) {
			require (LOYALTETHCONTRACT.getTokenDeadLine(_myTokenId) < block.timestamp , "To early owner cant withdraw");
			(bool success, ) = owner().call{value: balanceOfNftId[_myTokenId]}(""); //hum hum this needs a bit more security ?? reentrency ? 
			require (success, "transfert failed");
			balanceOfNftId[_myTokenId] = 0;
			LOYALTETHCONTRACT.triggActiveToken(_myTokenId);
		} else {//maybe an else if sender == nftOwner ?   this is redondent with the first requirement ?
			require (LOYALTETHCONTRACT.getTokenUsedById(_myTokenId) >= LOYALTETHCONTRACT.getTokenRequired(_myTokenId), "to early, user cant withdraw");
			(bool success, ) = msg.sender.call{value: balanceOfNftId[_myTokenId]}("");
			require (success, "transfert failed");
			balanceOfNftId[_myTokenId] = 0;
			LOYALTETHCONTRACT.triggActiveToken(_myTokenId);
		}
	}

	function getBalanceOfATokenId (uint256 _tokenId) external view returns (uint256) {
		return balanceOfNftId[_tokenId];
	}

	receive() external payable {}
}
