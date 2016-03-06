-- Copyright 2016 The Howl Developers
-- License: MIT (see LICENSE.md at the top-level directory of the distribution)

import app, config, mode, signal from howl
import Process from howl.io

append = table.insert

run_command = (contents) ->
  args = {}
  for arg in config.go_fmt_command\gmatch '%S+'
    append args, arg
  args.stdin = contents
  success, out, err, p = pcall Process.execute, args, stdin: contents
  if success and p.successful and err == ""
    return true, out
  
  return false, err or out

calculate_new_pos = (pos, before, after) ->
  -- adjust for whitespace changes made by go fmt
  new_pos = 1
  biter = before\sub(1, pos)\gmatch '.'
  aiter = after\gmatch '.'
  bch = biter()
  ach = aiter()
  while bch and ach
    if bch == ach
      bch = biter()
      ach = aiter()
      new_pos += 1
    elseif bch\match '%s'
      bch = biter()
    else
      ach = aiter()
      new_pos += 1
  new_pos-1

fmt = (buffer) ->
  log.info "Running #{config.go_fmt_command}..."
  before = buffer.text
  buffer.read_only = true
  success, result = run_command before
  buffer.read_only = false
  unless success
    log.error "#{config.go_fmt_command} error: #{result}"
    return
  log.info "#{config.go_fmt_command} completed"
  return if result == before

  editor = app\editor_for_buffer buffer
  if editor
    -- reload the contents, adjusting position
    pos = editor.cursor.pos
    top_line = editor.line_at_top
    buffer.text = result
    
    editor.cursor.pos = calculate_new_pos pos, before, result
    editor.line_at_top = top_line
  else
    buffer.text = result

{
  :fmt
}
