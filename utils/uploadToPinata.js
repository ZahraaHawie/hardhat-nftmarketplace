/* 

Store the image in IPFS
Store the Metadata in IPFS
Signup to pinata
Pinata is just an IPFS node, run by somebody else. 
And we can say, Hey, can you please pin this data for us. 
we are not going to upload files manuals we will do it programmatically

*/

const pinataSDK = require("@pinata/sdk");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

const pinataApiKey = process.env.PINATA_API_KEY || "";
const pinataApiSecret = process.env.PINATA_API_SECRET || "";
const pinata = pinataSDK(pinataApiKey, pinataApiSecret);

async function storeImages(imagesFilePath) {
  const fullImagesPath = path.resolve(imagesFilePath);
  const files = fs.readdirSync(fullImagesPath);
  let responses = [];
  console.log("Uploading to Pinata");
  for (fileIndex in files) {
    const readableStreamForFile = fs.createReadStream(
      `${fullImagesPath}/${files[fileIndex]}`
    );
    try {
      const response = await pinata.pinFileToIPFS(readableStreamForFile);
      responses.push(response);
    } catch (error) {
      console.log(error);
    }
  }
  return { responses, files };
}

async function storeTokenUriMetadata(metadata) {
  try {
    const response = await pinata.pinJSONToIPFS(metadata);
    return response;
  } catch (error) {
    console.log(error);
  }
  return null;
}

module.exports = { storeImages, storeTokenUriMetadata };

// async function storeImages(imagesFilePath) {
//   const fullImagesPath = path.resolve(imagesFilePath);
//   const files = fs.readdirSync(fullImagesPath);
//   let responses = [];
//   for (fileIndex in files) {
//     const readableStreamForFile = fs.createReadStream(
//       `${fullImagesPath}/${files[fileIndex]}`
//     );

// module.exports = { storeImages, storeTokeUriMetadata };
