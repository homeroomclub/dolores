turn = (nodes, state, context) ->
  for node in nodes
    if node.pattern == state.name || node.pattern.test? state.name
      if node.action?
        await node.action context, state
      if node.result?
        state.result = await node.result context, state
      else if node.next?
        original = state.name
        state.name = await node.next context, state
        console.log "#{original} -> #{state.name}"
        if node.nodes?
          await turn node.nodes, state, context
      return undefined
  # if we get here, no nodes matched, which is a bad state
  throw new Error "Unknown state [ #{state.name} ]"

runNetwork = (nodes, state, context) ->
  loop
    await turn nodes, state, context
    if state.result?
      return state.result

export {
  runNetwork
}