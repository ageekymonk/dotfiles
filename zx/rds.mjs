const { RDSClient, DescribeReservedDBInstancesCommand} = require("@aws-sdk/client-rds");
const { loadSharedConfigFiles} = require("@aws-sdk/shared-ini-file-loader")
const { fromIni } = require("@aws-sdk/credential-provider-ini");
const { fromProcessInit } = require("@aws-sdk/credential-provider-process")
const { from } = require('rxjs');

var fuzzy = require('fuzzy');
var inquirer = require('inquirer');
inquirer.registerPrompt('checkbox-plus', require('inquirer-checkbox-plus-prompt'));

var configFiles = await loadSharedConfigFiles()

const profileNameList = [ ...Object.keys(configFiles.configFile), ...Object.keys(configFiles.credentialsFile) ]

var questions = [
  {
    type: 'checkbox-plus',
    name: 'profiles',
    message: 'AWS Accounts?',
    choices: profileNameList,
    searchable: true,
    source: function(answersSoFar, input) {
      input = input || '';

      return new Promise(function(resolve) {

        var fuzzyResult = fuzzy.filter(input, profileNameList);

        var data = fuzzyResult.map(function(element) {
          return element.original;
        });

        resolve(data);

      });

    },
    default: ['default'],
  },
  {
    type: 'list',
    name: 'region',
    message: 'AWS Region?',
    choices: ["ap-southeast-2", "us-east-1", "us-west-1"],
    default: 'ap-southeast-2',
  }
]

async function setupAwsProfile(profileName, region) {
  var output = await $`aws-vault exec ${profileName} --region ${region} --json`
  var creds = JSON.parse(output.stdout)

  return {
    "accessKeyId": creds.AccessKeyId,
    "secretAccessKey": creds.SecretAccessKey,
    "sessionToken": creds.SessionToken,
    "expiration": creds.expiration
  };
}
const observable = from(questions);

inquirer.prompt(observable).ui.process.subscribe(handleAnswers);

var answers = {}

async function handleAnswers(current_answer) {
  answers[current_answer['name']] = current_answer['answer'];
  var bucketsList = []

  if ( (answers['profiles']) && (answers['region']) ) {
    for (var profile of answers['profiles']) {
      var creds = await setupAwsProfile(profile, answers['region']);
      const client = new RDSClient({ region: answers['region'], credentials: Object(creds) });
      const command = new DescribeReservedDBInstancesCommand({});
      try {
        // const results = client.send(command).then((results) => {
        //   bucketsList.push(...results.Buckets.map((elem) => elem.Name))
        // })
        const results = await client.send(command)
        bucketsList.push(...results.ReservedDBInstances.map((elem) => `${profile}: ${elem.Name}`))
      } catch (err) {
        console.error(err);
      }
    }

    inquirer.prompt(
      {
        type: 'checkbox-plus',
        name: 'buckets',
        message: 'Buckets?',
        searchable: true,
        source: function(answersSoFar, input) {
          input = input || '';

          return new Promise(function(resolve) {

            var fuzzyResult = fuzzy.filter(input, bucketsList);

            var data = fuzzyResult.map(function(element) {
              return element.original;
            });

            resolve(data);

          });

        },
        default: ['default'],
      })
  }
}
