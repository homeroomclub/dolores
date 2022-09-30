import { test, success } from "@dashkite/amen"
import print from "@dashkite/amen-console"

import assert from "@dashkite/assert"

import * as Type from "@dashkite/joy/type"
import { generic } from "@dashkite/joy/generic"

import * as DynamoDB from "../src/dynamodb"
import * as VPC from "../src/vpc"

import scenarios from "./scenarios"

import { target } from "./helpers"

do ->

  print await test "Dolores", [

    target "DynamoDB", do -> 
      [
      
        test "wrap/unwrap", do ->
          for name, value of scenarios.DynamoDB.wrap
            test name, ->
              assert.deepEqual value, 
                DynamoDB.unwrap DynamoDB.wrap value

      ]

    target "VPC", do ->

      [

        test "get", ->
          vpc = await VPC.get()
          assert vpc.id?
          assert.equal "default", vpc.name

        test "Subnet.list", ->
          subnets = await VPC.Subnet.list()
          assert subnets?
          assert subnets.length?
          for subnet in subnets
            console.log subnet.id
            assert subnet.id?
            assert subnet.zone?
            assert subnet.arn?

      ]
  
  ]