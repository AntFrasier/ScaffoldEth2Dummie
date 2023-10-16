import Link from "next/link";
import type { NextPage } from "next";
import { BugAntIcon, MagnifyingGlassIcon, SparklesIcon } from "@heroicons/react/24/outline";
import { MetaHeader } from "~~/components/MetaHeader";
import { useScaffoldContract, useScaffoldContractRead, useScaffoldContractWrite, useTransactor } from "~~/hooks/scaffold-eth";
import { useState } from "react";
import { EtherInput } from "~~/components/scaffold-eth";
import Image from "next/image";
import { parseEther } from "viem";
import { useAccount, useWalletClient } from "wagmi";




const Home: NextPage = () => {
  const [pizzaToBuyEthPrice, setPizzaToBuyEthPrice] = useState<bigint>();
  const [tokenId, setTokenId] =useState<bigint>();
  const {address:SignerAddress } = useAccount();
  // const [isLoading, setdisable] =useState<boolean>(false);

  const pizze :{image:string, name:string, description:string, price:string }[] = [
    {
      image:"/pizza1.jpg",
      name:"Marguarrita",
      description:"Tomatos, cheese, ham",
      price:"0.1"
    },
    {
      image:"/pizza2.jpg",
      name:"Quatro fromagi",
      description:"Tomatos, cheese 1, cheese 2, cheese 3, cheese 4",
      price:"0.2"
    },
    {
      image:"/pizza3.jpg",
      name:"La Parma",
      description:"Tomatos, cheese, ham, olive, mushrooms",
      price:"0.5"
    },
  ]
  
  const buyPizza = useScaffoldContractWrite({
    contractName:"PartnerVendorContract", 
    functionName:"receivePayement", 
    args:[tokenId], 
    value:pizzaToBuyEthPrice, 
    onBlockConfirmation: () => console.log("block confirmed !"), 
    },
  )

  const {data:nftContractAdd} = useScaffoldContractRead({
    contractName:"PartnerVendorContract",
    functionName:"LOYALTETHCONTRACT",
  })

  // const {data:nftContract} = useScaffoldContract({
  //   contractName:"LoyaltEthCards",
  // })
  const {data: walletClient} = useWalletClient();
  const { data: LoyaltEthContract } = useScaffoldContract({
    contractName: "LoyaltEthCards",
    walletClient,
    contractAddress: nftContractAdd,
  });

  const getMyTokensIds = async () => {
    const address = SignerAddress;
    if (!address) return [];
    const myTokensIds: bigint[] = [];
    await LoyaltEthContract?.read.balanceOf([address])
        .then(
            async (response) => {
            console.log("my balance : ", response);
            if (response) {
                for (let i=0; i<response; i++) {
                    const id = await LoyaltEthContract?.read.tokenOfOwnerByIndex([address, BigInt(i)]);
                    myTokensIds.push(id)
                }
            }
            console.log("myTokensIds : ", myTokensIds)})
    return myTokensIds;
  }

 const sendEthTxn = useTransactor();

const handleBuy = async (price:string)=>{
  const myTokensIds = await getMyTokensIds();
  let sendTo = await LoyaltEthContract?.read.owner();
  if (myTokensIds.length>0) {
    setTokenId(myTokensIds[0]);
    setPizzaToBuyEthPrice(parseEther(price))
    await buyPizza.writeAsync()
    
  }
  

    await sendEthTxn({
      to:sendTo,
      value:parseEther(price),
    })

  }

  return (
    <>
      <MetaHeader />
      <div className="flex items-center flex-col flex-grow pt-10">
        <div className="px-5">
          <h1 className="text-left mb-8">
            <span className="block text-2xl mb-2">Welcome to</span>
            <span className="block text-4xl font-bold">Pizze Dummies Vendor !</span>
          </h1>
          <p className="text-left text-lg">
            Connect your Wallet to order a Pizza !
          </p>
          <p className="text-left text-lg">
            If you don&#39;t have your LoyaltEth Nft Cards please mint one <a className="text-info" href={""} target="_blank"> here !</a>
          </p>
          <p className="text-left text-lg ">
           {pizze?.map((pizza)=> {
           return (
              <div key={pizza.name} className="bg-info my-5 px-5 py-3 rounded-lg" > 
                
                <div className="flex flex-row justify-between items-center">
                  <div className="flex">
                    <Image className="rounded-full" alt="Pizza" src={`${pizza.image}`} width={100} height={100}/>
                    <div className="flex flex-col justify-center mx-5">
                      <h3>{pizza.name}</h3>
                      <p className="m-0 font-extralight">{pizza.description}</p>
                    </div>
                  </div>
                  <div className="flex flex-col items-end max-w-[150px] gap-1">
                    <p className="m-0"><EtherInput onChange={() => pizza.price} value={pizza.price}/></p>
                    <button className="btn-secondary rounded-full w-[75px]" type="button" disabled={buyPizza?.isError} onClick={ () => handleBuy(pizza.price)}>
                      Buy
                    </button>
                  </div>
                </div>
              </div>)}
           )}
          </p>
        </div>

        <div className="flex-grow bg-base-300 w-full mt-16 px-8 py-12">
          <div className="flex justify-center items-center gap-12 flex-col sm:flex-row">
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <BugAntIcon className="h-8 w-8 fill-secondary" />
              <p>
                Tinker with your smart contract using the{" "}
                <Link href="/debug" passHref className="link">
                  Debug Contract
                </Link>{" "}
                tab.
              </p>
            </div>
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <SparklesIcon className="h-8 w-8 fill-secondary" />
              <p>
                Experiment with{" "}
                <Link href="/example-ui" passHref className="link">
                  Example UI
                </Link>{" "}
                to build your own UI.
              </p>
            </div>
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <MagnifyingGlassIcon className="h-8 w-8 fill-secondary" />
              <p>
                Explore your local transactions with the{" "}
                <Link href="/blockexplorer" passHref className="link">
                  Block Explorer
                </Link>{" "}
                tab.
              </p>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
