import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; 
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

message NftWithdrawal {
  queryId: Int as uint64;
  nftAddress: Address;
}


contract Task4 with Deployable {
  seed: Int as uint128;


  prevOwner: Address?;
  nft_address: Address?;
  lock_until: Int = 0;
  
  init(seed: Int) {
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
  }

  receive(msg: OwnershipAssigned) {
    if(self.prevOwner != null){
      send(SendParameters{
        to: sender(),
        value: 0,
        mode: SendRemainingValue + SendIgnoreErrors,
        body: Transfer{
          queryId: msg.queryId,
          newOwner: msg.prevOwner,
          responseDestination: msg.prevOwner,
          customPayload: null,
          forwardAmount: 0,
          forwardPayload: emptySlice()
        }.toCell()
      });
    }else{
      self.nft_address = sender();
      self.prevOwner = msg.prevOwner;
      self.lock_until = now() + msg.forwardPayload.loadUint(32);
    }
  }

  receive(msg: NftWithdrawal) {
   //require(msg.nftAddress == self.nft_address, "NFT adress doent match");
   //require(self.nft_address != null, "No nft");
   require(sender() == self.prevOwner, "Invalid sender");
    if(self.lock_until > now()){
      self.reply("NFT is still locked".asComment());
    }else{
      //self.lock_until = 0;
      self.nft_address = null;
      self.prevOwner = null;
      send(SendParameters{
        to: msg.nftAddress,
        value: 0,
        mode: SendRemainingValue + SendIgnoreErrors,
        body: Transfer{
          queryId: msg.queryId,
          newOwner: sender(),
          responseDestination: sender(),
          customPayload: null,
          forwardAmount: 0,
          forwardPayload: emptySlice()
        }.toCell()
      });
    }
  }

  get fun time(): Int {
    return self.lock_until - now();
  }

  get fun nft(): Address? {
        return self.nft_address;
 }

  get fun owner(): Address? {
      return self.prevOwner;
  }
}