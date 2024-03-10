const { DynamoDBClient, ListTablesCommand } = require("@aws-sdk/client-dynamodb");


var inquirer = require('inquirer');

const questions = [
  {
    type: 'list',
    name: 'region',
    message: 'AWS Region?',
    choices: ["ap-southeast-2", "us-east-1"],
    default: 'ap-southeast-2',
  }
]

inquirer
  .prompt(questions)
  .then((answers) => {
    (async () => {
      const client = new DynamoDBClient({ region: answers['region'] });
      const command = new ListTablesCommand({});
      try {
        const results = await client.send(command);
        console.log(results.TableNames.join("\n"));
      } catch (err) {
        console.error(err);
      }
    })();
  })
  .catch((error) => {
    console.log(error)
    if (error.isTtyError) {
      // Prompt couldn't be rendered in the current environment
    } else {
      // Something else went wrong
    }
  });
