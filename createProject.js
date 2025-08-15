// change the address to deployed contract address
const contractAddr = "";

async function main() {
  const CrowdTank = await ethers.getContractFactory("CrowdTank");
  const crowdTank= await CrowdTank.attach(contractAddr);

  //play around with variables
  const name = " name";
  const description= "description";
  const fundingGoal = 1000000;
  const durationSeconds = 100;
  const id = 101;

  // calling the transaction
  const txn = await  crowdTank.createProject(name,description,fundingGoal,durationSeconds,id);
  console.log(" Txn Status -> ",  txn.hash);
  console.log("transaction -> ",txn);
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});
