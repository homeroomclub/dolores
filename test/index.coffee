import { test, success } from "@dashkite/amen"
import print from "@dashkite/amen-console"

import assert from "@dashkite/assert"

import * as DynamoDB from "../src/dynamodb"

import scenarios from "./scenarios"

do ->

  print await test "Dolores", [

    test "DynamoDB", [
      
      await test "wrap/unwrap", do ->
        for name, value of scenarios.DynamoDB.wrap
          test name, ->
            assert.deepEqual value, 
              DynamoDB.unwrap DynamoDB.wrap value

    ]
  ]