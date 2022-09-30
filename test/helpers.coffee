import { test } from "@dashkite/amen"

import * as Type from "@dashkite/joy/type"
import { generic } from "@dashkite/joy/generic"

isActive = do ({ active } = {}) -> 
  active = process.env.target?.split /\s+/
  ( targets ) ->
    !active? ||
      ( targets.find (target) -> active.includes target.toLowerCase() )?

isTestable = ( value ) -> ( Type.isArray value  ) || ( Type.isFunction value )

target = generic name: "target"

generic target, Type.isArray, Type.isObject, isTestable, ( tx, spec, f ) ->
  if isActive tx then await test spec, f else test spec.description

generic target, Type.isArray, Type.isString, isTestable, ( tx, name, f ) ->
  target tx, description: name, f

generic target, Type.isString, Type.isString, isTestable, ( t, name, f ) ->
  target [ t ], description: name, f

generic target, Type.isString, isTestable, ( name, f ) ->
  target [ name ], description: name, f

export {
  target
}