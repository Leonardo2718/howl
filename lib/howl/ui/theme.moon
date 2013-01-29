import Gdk, Gtk from lgi
import File from howl.fs
import config from howl
import style, colors, highlight from howl.ui
import PropertyTable, Sandbox from howl.aux

css_provider = Gtk.CssProvider!
screen = Gdk.Screen\get_default!
Gtk.StyleContext.add_provider_for_screen screen, css_provider, 600

css_template = [[
GtkWindow.main {
  ${window_background};
}

.editor {
  border-width: 1px 3px 3px 1px;
  background-color: ${editor_border_color};
}

.sci_box {
  background-color: ${editor_divider_color};
}

.header {
  ${header_background};
  color: ${header_color};
  font: ${header_font};
  border-width: 0px;
}

.footer {
  ${footer_background};
  color: ${footer_color};
  font: ${footer_font};
  border-width: 0px;
}

.status {
  font: ${status_font};
  color: ${status_color};
}

.readline_box {
  border-width: 1px 3px 3px 1px;
  background-color: ${editor_border_color};
}
]]

status_template = [[
.status_${name} {
  font: ${font};
  color: ${color};
}
]]

available = {}
theme_files = {}
current_theme = nil
current_theme_file = nil
theme_active = false

interpolate = (content, values) ->
  content\gsub '%${([%a_]+)}', values

parse_background = (value, theme_dir) ->
  if value\match '^%s*#%x+%s*$'
    'background-color: ' .. value
  elseif value\find '-gtk-gradient', 1, true
    'background-image: ' .. value
  else
    if not File.is_absolute value
      value = tostring theme_dir\join(value).path
    "background-image: url('" .. value .. "')"

parse_font = (font = {}) ->
  size = config.font_size
  desc = config.font
  desc ..= ' bold' if font.bold
  desc ..= ' italic' if font.italic
  desc ..= ' ' .. size if size
  desc

indicator_css = (id, def) ->
  clazz = '.indic_' .. id
  indic_css = clazz .. ' { '
  if def.color then indic_css ..= 'color: ' .. def.color .. '; '
  indic_css ..= 'font: ' .. parse_font(def.font).. '; '
  indic_css ..= ' }\n'
  indic_css

indicators_css = (indicators = {}) ->
  css = indicator_css 'default', indicators.default or {}
  for id, def in pairs indicators
    css ..= indicator_css id, def if id != 'default'
  css

status_css = (status) ->
  css = ''
  for level in *{'info', 'warning', 'error'}
    values = status[level]
    if values
      font = values.font or status.font
      color = values.color or status.color
      css ..= interpolate status_template,
        name: level
        font: parse_font font
        color: color
  css

theme_css = (theme, file) ->
  dir = file.parent
  window = theme.window
  status = window.status
  editor = theme.editor
  hdr = editor.header
  footer = editor.footer
  tv_title = hdr.title
  indicators = editor.indicators
  values =
    window_background: parse_background(window.background, dir)
    status_font: parse_font status.font
    status_color: status.color
    editor_border_color: editor.border_color
    editor_divider_color: editor.divider_color
    header_background: parse_background(hdr.background, dir)
    header_color: hdr.color
    header_font: parse_font hdr.font
    footer_background: parse_background(footer.background, dir)
    footer_color: footer.color
    footer_font: parse_font footer.font
  css = interpolate css_template, values
  css ..= indicators_css indicators
  css ..= status_css status
  css

load_theme = (file) ->
  chunk = loadfile(file.path)
  box = Sandbox colors
  box\put :highlight
  box chunk

apply_theme = ->
  css = theme_css current_theme, current_theme_file
  status = css_provider\load_from_data css
  error 'Error loading theme "' .. theme.name .. '"' if not status
  style.set_for_theme current_theme
  highlight.set_for_theme current_theme

set_theme = (name) ->
  if name == nil
    current_theme = nil
    theme_active = false
    return

  file = theme_files[name]
  error 'No theme found with name "' .. name .. '"' if not file
  theme = load_theme file
  theme.name = name
  current_theme = theme
  current_theme_file = file
  apply_theme if theme_active

with config
  .define
    name: 'font'
    description: 'The main font used within the application'
    default: 'Liberation Mono'
    type_of: 'string'

  .define
    name: 'font_size'
    description: 'The size of the main font'
    default: 11
    type_of: 'number'

config.watch 'font', (name, value) -> apply_theme! if current_theme
config.watch 'font_size', (name, value) -> apply_theme! if current_theme

return PropertyTable {
  current:
    get: -> current_theme
    set: (_, theme) -> set_theme theme

  available:
    get: -> available

  register: (name, file) ->
    error 'name not specified for theme', 2 if not name
    error 'file not specified for theme', 2 if not file
    available[#available + 1] = name
    theme_files[name] = file

  apply: ->
    return if theme_active
    error 'No theme set to apply', 2 unless current_theme
    apply_theme!
    theme_active = true
}