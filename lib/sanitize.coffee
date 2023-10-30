## https://github.com/cure53/DOMPurify

import createDOMPurify from 'dompurify'
DOMPurify = null
queueMicrotask -> # wait for JSDOM to load on server
  DOMPurify = createDOMPurify window ? new JSDOM('').window

  DOMPurify.setConfig
    ADD_TAGS: [
      'annotation', 'semantics'  # from KaTeX; encoding sanitized below
      'use'  # href sanitized below
    ]
    FORBID_TAGS: [
      'style'  # can mess with global CSS
    ]

  ## Individual attribute sanitization
  DOMPurify.addHook 'uponSanitizeAttribute', (node, event) ->
    nodeName = -> node.nodeName.toLowerCase()
    switch event.attrName
      when 'style'
        event.attrValue = event.attrValue
        ## First remove all CSS comments, replacing them with space to avoid
        ## accidentally forming a /* from surrounding "/" and "*".
        .replace cssCommentRegex, ' '
        ## We used to always forbid position:absolute, but KaTeX needs them
        ## (see e.g. `\not`).  But we do need to forbid position:fixed, because
        ## this can break outside the overflow:auto constraint of message body.
        .replace /\bposition\s*:\s*fixed/ig, ''
      when 'class'
        ## Implement class whitelist
        event.attrValue = event.attrValue
        .replace cssCommentRegex, ' '
        .split /\s+/
        .filter allowedClassesSet.has.bind allowedClassesSet
        .join ' '
      when 'type'
        ## Remove type attribute from <input>s; set to "checkbox" below
        event.keepAttr = false if nodeName() == 'input'
      when 'href', 'xlink:href', 'action'
        ## SVG <use> is insecure if it has protocols:
        ## https://insert-script.blogspot.com/2014/02/svg-fun-time-firefox-svg-vector.html
        if nodeName() == 'use'
          event.keepAttr = event.attrValue.startsWith '#'
      when 'id'
        ## Localize ids (more processing done in formats)
        event.attrValue = 'MESSAGE_' + event.attrValue
  ## Bulk attribute sanitization
  DOMPurify.addHook 'afterSanitizeAttributes', (node) ->
    switch node.nodeName.toLowerCase()
      when 'input'
        ## Force all <input>s to have type="checkbox" and be disabled
        node.setAttribute 'type', 'checkbox'
        node.setAttribute 'disabled', ''
      when 'annotation'
        ## Force MathML <annotation> to have encoding set as KaTeX does,
        ## to avoid potential exploits with encoding="text/html" and maybe SVG.
        ## See https://github.com/cure53/DOMPurify/blob/81ae4bd8ebfefd5700dd3c7a908725efaae931e6/test/fixtures/expect.js#L1095
        node.setAttribute 'encoding', 'application/x-tex'

## https://stackoverflow.com/questions/9329552/explain-regex-that-finds-css-comments
cssCommentRegex = /\/\*[^*]*\*+(?:[^/*][^*]*\*+)*\//g

## Whitelist for class argument, to avoid access to e.g. classes with
## position:fixed, and to avoid creating buttons with automatic click handlers.
allowedClasses = [
  'deleted', 'unpublished', 'private', 'warning'  # warnings from <img>
  'coauthor-link' # coauthor:... autoformat
  'natural'       # don't mess with images; generated from coauthor-link
  'slant'        # generated by \textsl
  'itemlab'      # generated by \item
  'noitemlab'    # generated by \item
  'thm'          # generated by \begin{theorem} etc.
  'pull-right'   # generated by \end{proof}
  'clearfix'     # generated by \end{proof}
  'katex-error'  # generated by math
  'nonmath'      # generated by math
  'highlight'    # generated by search
  'center'       # generated by \begin{center}
  'label', 'label-danger', 'alert', 'alert-danger'  # generated by bad formatting
  'bad-file', 'empty-file', 'odd-file'  # generated by files
  # From packages:
  'task-list', 'task-list-item', 'checkbox'  # generated by markdown-it-task-checkbox
  'fas', 'far', 'fa-check-square', 'fa-square'  # our replacement for disabled checkboxes
  # highlight.js
  'hljs', 'hljs-addition', 'hljs-attr', 'hljs-attribute', 'hljs-built_in', 'hljs-builtin-name', 'hljs-bullet', 'hljs-comment', 'hljs-deletion', 'hljs-emphasis', 'hljs-keyword', 'hljs-link', 'hljs-literal', 'hljs-meta', 'hljs-name', 'hljs-number', 'hljs-params', 'hljs-quote', 'hljs-regexp', 'hljs-section', 'hljs-selector-class', 'hljs-selector-id', 'hljs-selector-tag', 'hljs-string', 'hljs-strong', 'hljs-symbol', 'hljs-tag', 'hljs-template-variable', 'hljs-title', 'hljs-type', 'hljs-variable'
  # KaTeX:
  'mbin', 'mclose', 'minner', 'mopen', 'mrel', 'mord', 'mop', 'mpunct', 'mtight'
  # Above exist but not actually styled so not caught by the following:
  # python -c 'import re; print(sorted(set(x.lstrip(".") for x in re.findall(r"\.[-a-zA-Z_][-\w]*", open("node_modules/katex/dist/katex.css").read()))))'
  'accent', 'accent-body', 'accent-full', 'amsrm', 'angl', 'anglpad', 'arraycolsep', 'base', 'boldsymbol', 'boxpad', 'brace-center', 'brace-left', 'brace-right', 'cancel-lap', 'cancel-pad', 'cd-arrow-pad', 'cd-label-left', 'cd-label-right', 'cd-vert-arrow', 'clap', 'col-align-c', 'col-align-l', 'col-align-r', 'com', 'delim-size1', 'delim-size4', 'delimcenter', 'delimsizing', 'eqn-num', 'fbox', 'fcolorbox', 'fix', 'fleqn', 'fontsize-ensurer', 'frac-line', 'halfarrow-left', 'halfarrow-right', 'hbox', 'hdashline', 'hide-tail', 'hline', 'inner', 'katex', 'katex-display', 'katex-html', 'katex-mathml', 'katex-version', 'large-op', 'leqno', 'llap', 'mainrm', 'mathbb', 'mathbf', 'mathboldsf', 'mathcal', 'mathfrak', 'mathit', 'mathitsf', 'mathnormal', 'mathrm', 'mathscr', 'mathsf', 'mathtt', 'mfrac', 'mml-eqn-num', 'mover', 'mspace', 'msupsub', 'mtable', 'mtr-glue', 'mult', 'munder', 'newline', 'nulldelimiter', 'op-limits', 'op-symbol', 'overlay', 'overline', 'overline-line', 'pstrut', 'reset-size1', 'reset-size10', 'reset-size11', 'reset-size2', 'reset-size3', 'reset-size4', 'reset-size5', 'reset-size6', 'reset-size7', 'reset-size8', 'reset-size9', 'rlap', 'root', 'rule', 'size1', 'size10', 'size11', 'size2', 'size3', 'size4', 'size5', 'size6', 'size7', 'size8', 'size9', 'sizing', 'small-op', 'sout', 'sqrt', 'stretchy', 'strut', 'svg-align', 'tag', 'textbb', 'textbf', 'textboldsf', 'textfrak', 'textit', 'textitsf', 'textrm', 'textscr', 'textsf', 'texttt', 'thinbox', 'ttf', 'underline', 'underline-line', 'vbox', 'vertical-separator', 'vlist', 'vlist-r', 'vlist-s', 'vlist-t', 'vlist-t2', 'woff', 'woff2', 'x-arrow', 'x-arrow-pad'
]
allowedClassesSet = new Set allowedClasses

window.sanitized = [] if Meteor.isClient

@sanitize = (html) ->
  htmlSanitized = DOMPurify.sanitize html
  if Meteor.isClient and htmlSanitized != html
    unless window.sanitized.length
      console.warn "Sanitized some messages' HTML; see global variable `sanitized` for details."
    window.sanitized.push
      removed: DOMPurify.removed
      before: html
      after: htmlSanitized
  htmlSanitized
