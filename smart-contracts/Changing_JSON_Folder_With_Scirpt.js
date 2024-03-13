

////////////////////////////////////////Editing Json files/////////////////////////////////////////////////

const fs = require('fs');
const path = require('path');

const folderPath = './metadata/metadata';

fs.readdir(folderPath, (err, files) => {
  if (err) throw err;

                    
  files.forEach((file,index) => {
    if (path.extname(file) === '.json') {
      const filePath = path.join(folderPath, file);
      // Read the JSON object
      const fileContent = fs.readFileSync(filePath, 'utf8');
      const jsonData = JSON.parse(fileContent);
      
      //Fields that you wants to change
      jsonData.name = `Name/ #${file.slice(0, -5)}`;   //slice function will find the current no.file
      jsonData.description = "Description";
      jsonData.image = `image/${file.slice(0, -5)}.png`;

      // Write the modified JSON object back to the file
      const newFileContent = JSON.stringify(jsonData, null, 2);

      fs.writeFileSync(filePath, newFileContent, 'utf8');
      
    }
  });

  console.log("Done")
});




////////////////////////////////////////Making Json files/////////////////////////////////////////////////

const fs = require('fs');
const path = require('path');
const folderPath = './metadata'; // Path to the folder where you want to save the files
// Create the folder if it doesn't exist
if (!fs.existsSync(folderPath)){
    fs.mkdirSync(folderPath, { recursive: true });
}
for (let index = 1; index <= 200; index++) {
    const serialNumber = 2400000 + index;
    const fileName = `${index}.json`;
    const fileContent = {
        name: `K1-${serialNumber}`,
        description: `KimberLite Collectibles, NFT Serial Number: K1-${serialNumber}`,
        image: `https://bafybeibbrhf2bokirbw5yl7xrkdcckftmlicycpysveb3dkrfkp5uevfpu.ipfs.nftstorage.link/K1-${serialNumber}.png`
    };
    fs.writeFile(path.join(folderPath, fileName), JSON.stringify(fileContent, null, 2), (err) => {
        if (err) {
            console.error(err);
            return;
        }
        console.log(`${fileName} was created successfully`);
    });
}
