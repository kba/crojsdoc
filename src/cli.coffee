fs = require 'fs'
glob = require 'glob'
walkdir = require 'walkdir'
{basename,dirname,join,resolve} = require 'path'

readConfig = (options, paths) ->
  {safeLoad} = require 'js-yaml'
  try
    config = safeLoad fs.readFileSync(join(process.cwd(), 'crojsdoc.yaml'), 'utf-8')
    if config.hasOwnProperty 'output'
      options.output = config.output
    if config.hasOwnProperty 'title'
      options.title = config.title
    if config.hasOwnProperty 'quite'
      options.quite = config.quite is true
    if  config.hasOwnProperty 'files'
      options.files = config.files is true
    if config.hasOwnProperty('readme') and typeof config.readme is 'string'
      options.readme = config.readme
    if config.hasOwnProperty 'external-types'
      options['external-types'] = config['external-types']
    if config.hasOwnProperty 'sources'
      if Array.isArray config.sources
        [].push.apply paths, config.sources
      else
        paths.push config.sources
    if config.hasOwnProperty 'github'
      options.github = config.github
      if options.github.branch is undefined
        options.github.branch = 'master'

parseArguments = (options, paths) ->
  {OptionParser} = require 'optparse'
  switches = [
    [ '-o', '--output DIRECTORY', 'Output directory' ]
    [ '-t', '--title TITLE', 'Document Title' ]
    [ '-q', '--quite', 'less output' ]
    [ '-r', '--readme DIRECTORY', 'README.md directory path']
    [ '-f', '--files', 'included source files' ]
    [ '--external-types JSONFILE', 'external type definitions' ]
  ]
  parser = new OptionParser switches
  parser.on '*', (opt, value) ->
    if value is undefined
      value = true
    options[opt] = value
  [].push.apply paths, parser.parse process.argv.slice 2

readExternalTypes = (external_types, types) ->
  return if not external_types

  if typeof external_types is 'string'
    try
      content = fs.readFileSync(external_types, 'utf-8').trim()
      try
        external_types = JSON.parse content
      catch e
        console.log "external-types: Invalid JSON file"
    catch e
      console.log "external-types: Cannot open #{external_types}"

  if typeof external_types is 'object'
    for type, url of external_types
      types[type] = url

getOptionsAndPaths = ->
  options =
    project_dir: process.cwd()
    types:
      # Links for pre-known types
      Object: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Object'
      Boolean: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Boolean'
      String: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/String'
      Array: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Array'
      Number: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Number'
      Date: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Date'
      Function: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Function'
      RegExp: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/RegExp'
      Error: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Error'
      undefined: 'https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/undefined'
  paths = []

  readConfig options, paths
  parseArguments options, paths
  readExternalTypes options['external-types'], options.types

  options.output_dir = resolve options.project_dir, options.output or 'doc'

  return [options, paths]

readFiles = (paths, options) ->
  project_dir_re = new RegExp("^" + options.project_dir)
  contents = []
  for path in paths
    base_path = path = resolve options.project_dir, path
    base_path = dirname base_path while /[*?]/.test basename(base_path)
    glob.sync(path).forEach (path) =>
      if fs.statSync(path).isDirectory()
        list = walkdir.sync path
      else
        list = [path]
      for file in list
        continue if fs.statSync(file).isDirectory()
        data = fs.readFileSync(file, 'utf-8').trim()
        continue if not data
        contents.push path: file.replace(project_dir_re, ''), file: file.substr(path.length+1), data: data
  try
    data = fs.readFileSync "#{options.readme or options.project_dir}/README.md", 'utf-8'
    contents.push path: '', file: 'README', data: data
  return contents

[options, paths] = getOptionsAndPaths()
contents = readFiles paths, options
result = require('./collect') contents, options
require('./render') result, options
