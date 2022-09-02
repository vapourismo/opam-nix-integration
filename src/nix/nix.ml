include Expr

module Pat = struct
  include Expr.Pat

  let render = Print.render_pattern
end

include Print
