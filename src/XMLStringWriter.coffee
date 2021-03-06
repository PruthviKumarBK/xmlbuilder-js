XMLDeclaration = require './XMLDeclaration'
XMLDocType = require './XMLDocType'

XMLCData = require './XMLCData'
XMLComment = require './XMLComment'
XMLElement = require './XMLElement'
XMLRaw = require './XMLRaw'
XMLText = require './XMLText'
XMLProcessingInstruction = require './XMLProcessingInstruction'
XMLDummy = require './XMLDummy'

XMLDTDAttList = require './XMLDTDAttList'
XMLDTDElement = require './XMLDTDElement'
XMLDTDEntity = require './XMLDTDEntity'
XMLDTDNotation = require './XMLDTDNotation'

XMLWriterBase = require './XMLWriterBase'

# Prints XML nodes as plain text
module.exports = class XMLStringWriter extends XMLWriterBase


  # Initializes a new instance of `XMLStringWriter`
  #
  # `options.pretty` pretty prints the result
  # `options.indent` indentation string
  # `options.newline` newline sequence
  # `options.offset` a fixed number of indentations to add to every line
  # `options.allowEmpty` do not self close empty element tags
  # 'options.dontPrettyTextNodes' if any text is present in node, don't indent or LF
  # `options.spaceBeforeSlash` add a space before the closing slash of empty elements
  constructor: (options) ->
    super(options)

  document: (doc, options) ->
    options = @filterOptions options
    options.textispresent = false
    r = ''
    for child in doc.children
      # skip dummy nodes
      if child instanceof XMLDummy then continue

      r += switch
        when child instanceof XMLDeclaration then @declaration child, options, 0
        when child instanceof XMLDocType     then @docType     child, options, 0
        when child instanceof XMLComment     then @comment     child, options, 0
        when child instanceof XMLProcessingInstruction then @processingInstruction child, options, 0
        else @element child, options, 0

    # remove trailing newline
    if options.pretty and r.slice(-options.newline.length) == options.newline
      r = r.slice(0, -options.newline.length)

    return r

  attribute: (att, options, level) ->
    ' ' + att.name + '="' + att.value + '"'

  cdata: (node, options, level) ->
    @space(node, options, level) + '<![CDATA[' + node.text + ']]>' + @endline(node, options, level)

  comment: (node, options, level) ->
    @space(node, options, level) + '<!-- ' + node.text + ' -->' + @endline(node, options, level)

  declaration: (node, options, level) ->
    r = @space(node, options, level)
    r += '<?xml version="' + node.version + '"'
    r += ' encoding="' + node.encoding + '"' if node.encoding?
    r += ' standalone="' + node.standalone + '"' if node.standalone?
    r += options.spaceBeforeSlash + '?>'
    r += options.newline

    return r

  docType: (node, options, level) ->
    level or= 0

    r = @space(node, options, level)
    r += '<!DOCTYPE ' + node.root().name

    # external identifier
    if node.pubID and node.sysID
      r += ' PUBLIC "' + node.pubID + '" "' + node.sysID + '"'
    else if node.sysID
      r += ' SYSTEM "' + node.sysID + '"'

    # internal subset
    if node.children.length > 0
      r += ' ['
      r += options.newline
      for child in node.children
        r += switch
          when child instanceof XMLDTDAttList  then @dtdAttList  child, options, level + 1
          when child instanceof XMLDTDElement  then @dtdElement  child, options, level + 1
          when child instanceof XMLDTDEntity   then @dtdEntity   child, options, level + 1
          when child instanceof XMLDTDNotation then @dtdNotation child, options, level + 1
          when child instanceof XMLCData       then @cdata       child, options, level + 1
          when child instanceof XMLComment     then @comment     child, options, level + 1
          when child instanceof XMLProcessingInstruction then @processingInstruction child, options, level + 1
          else throw new Error "Unknown DTD node type: " + child.constructor.name
      r += ']'

    # close tag
    r += options.spaceBeforeSlash + '>'
    r += options.newline

    return r

  element: (node, options, level) ->
    level or= 0
    textispresentwasset = false

    if options.textispresent
      options.newline = ''
      options.pretty = false
    else
      options.newline = options.newlineDefault
      options.pretty = options.prettyDefault

    space = @space(node, options, level)

    r = ''

    # open tag
    r += space + '<' + node.name

    # attributes
    for own name, att of node.attributes
      r += @attribute att, level, options

    if node.children.length == 0 or node.children.every((e) -> e.value == '')
      # empty element
      if options.allowEmpty
        r += '></' + node.name + '>' + @endline(node, options, level)
      else
        r += options.spaceBeforeSlash + '/>' + @endline(node, options, level)
    else if options.pretty and node.children.length == 1 and node.children[0].value?
      # do not indent text-only nodes
      r += '>'
      r += node.children[0].value
      r += '</' + node.name + '>' + @endline(node, options, level)
    else
      # if ANY are a text node, then suppress pretty now
      if options.dontPrettyTextNodes
        for child in node.children
          if child.value?
            options.textispresent++
            textispresentwasset = true
            break

      if options.textispresent
        options.newline = ''
        options.pretty = false
        space = @space(node, options, level)

      # close the opening tag, after dealing with newline
      r += '>' + @endline(node, options, level)
      # inner tags
      for child in node.children
        r += switch
          when child instanceof XMLCData   then @cdata   child, options, level + 1
          when child instanceof XMLComment then @comment child, options, level + 1
          when child instanceof XMLElement then @element child, options, level + 1
          when child instanceof XMLRaw     then @raw     child, options, level + 1
          when child instanceof XMLText    then @text    child, options, level + 1
          when child instanceof XMLProcessingInstruction then @processingInstruction child, options, level + 1
          when child instanceof XMLDummy   then ''
          else throw new Error "Unknown XML node type: " + child.constructor.name

      if textispresentwasset
        options.textispresent--

      if !options.textispresent
        options.newline = options.newlineDefault
        options.pretty = options.prettyDefault

      # close tag
      r += space + '</' + node.name + '>' + @endline(node, options, level)

    return r

  processingInstruction: (node, options, level) ->
    r = @space(node, options, level) + '<?' + node.target
    r += ' ' + node.value if node.value
    r += options.spaceBeforeSlash + '?>' + @endline(node, options, level)

    return r

  raw: (node, options, level) ->
    @space(node, options, level) + node.value + @endline(node, options, level)

  text: (node, options, level) ->
    @space(node, options, level) + node.value + @endline(node, options, level)

  dtdAttList: (node, options, level) ->
    r = @space(node, options, level) + '<!ATTLIST ' + node.elementName + ' ' + node.attributeName + ' ' + node.attributeType
    r += ' ' + node.defaultValueType if node.defaultValueType != '#DEFAULT'
    r += ' "' + node.defaultValue + '"' if node.defaultValue
    r += options.spaceBeforeSlash + '>' + @endline(node, options, level)

    return r

  dtdElement: (node, options, level) ->
    @space(node, options, level) + '<!ELEMENT ' + node.name + ' ' + node.value + options.spaceBeforeSlash + '>' + @endline(node, options, level)

  dtdEntity: (node, options, level) ->
    r = @space(node, options, level) + '<!ENTITY'
    r += ' %' if node.pe
    r += ' ' + node.name
    if node.value
      r += ' "' + node.value + '"'
    else
      if node.pubID and node.sysID
        r += ' PUBLIC "' + node.pubID + '" "' + node.sysID + '"'
      else if node.sysID
        r += ' SYSTEM "' + node.sysID + '"'
      r += ' NDATA ' + node.nData if node.nData
    r += options.spaceBeforeSlash + '>' + @endline(node, options, level)

    return r

  dtdNotation: (node, options, level) ->
    r = @space(node, options, level) + '<!NOTATION ' + node.name
    if node.pubID and node.sysID
      r += ' PUBLIC "' + node.pubID + '" "' + node.sysID + '"'
    else if node.pubID
      r += ' PUBLIC "' + node.pubID + '"'
    else if node.sysID
      r += ' SYSTEM "' + node.sysID + '"'
    r += options.spaceBeforeSlash + '>' + @endline(node, options, level)

    return r

  openNode: (node, options, level) ->
    level or= 0

    if node instanceof XMLElement
      r = @space(node, options, level) + '<' + node.name

      # attributes
      for own name, att of node.attributes
        r += @attribute att, options, level

      r += (if node.children then '>' else '/>') + @endline(node, options, level)

      return r
    else # if node instanceof XMLDocType
      r = @space(node, options, level) + '<!DOCTYPE ' + node.rootNodeName

      # external identifier
      if node.pubID and node.sysID
        r += ' PUBLIC "' + node.pubID + '" "' + node.sysID + '"'
      else if node.sysID
        r += ' SYSTEM "' + node.sysID + '"'

      # internal subset
      r += (if node.children then ' [' else '>') + @endline(node, options, level)

      return r

  closeNode: (node, options, level) ->
    level or= 0

    if node instanceof XMLElement
      @space(node, options, level) + '</' + node.name + '>' + @endline(node, options, level)
    else # if node instanceof XMLDocType
      @space(node, options, level) + ']>' + @endline(node, options, level)
