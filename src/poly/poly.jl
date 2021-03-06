export spoly, PolyRing, coeff, coeffs_expos, degree, exponent!, isgen, content,
       exponent, lead_exponent, ngens, degree_bound, primpart, @PolynomialRing,
       has_global_ordering, symbols

###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent(p::spoly) = p.parent

base_ring(R::PolyRing{T}) where T <: Nemo.RingElem = R.base_ring

base_ring(p::spoly) = base_ring(parent(p))

elem_type(::Type{PolyRing{T}}) where T <: Nemo.RingElem = spoly{T}

parent_type(::Type{spoly{T}}) where T <: Nemo.RingElem = PolyRing{T}

@doc Markdown.doc"""
    ngens(R::PolyRing)
> Return the number of variables in the given polynomial ring.
"""
ngens(R::PolyRing) = Int(libSingular.rVar(R.ptr))

@doc Markdown.doc"""
    has_global_ordering(R::PolyRing)
> Return `true` if the given polynomial has a global ordering, i.e. if $1 < x$ for
> each variable $x$ in the ring. This include `:lex`, `:deglex` and `:degrevlex`
> orderings..
"""
has_global_ordering(R::PolyRing) = Bool(libSingular.rHasGlobalOrdering(R.ptr))

@doc Markdown.doc"""
    characteristic(R::PolyRing)
> Return the characteristic of the polynomial ring, i.e. the characteristic of the
> coefficient ring.
"""
characteristic(R::PolyRing) = Int(libSingular.rChar(R.ptr))

function gens(R::PolyRing)
   n = ngens(R)
   return [R(libSingular.rGetVar(Cint(i), R.ptr)) for i = 1:n]
end

@doc Markdown.doc"""
    symbols(R::PolyRing)
> Return symbols for the generators of the polynomial ring $R$.
"""
function symbols(R::PolyRing)
   io = IOBuffer();
   symbols = Array{Symbol,1}(undef, 0)
   for g in gens(R)
      show(io,g)
      push!(symbols, Symbol(String(take!(io))))
   end
   return symbols
end


@doc Markdown.doc"""
    degree_bound(R::PolyRing)
> Return the internal degree bound in each variable, enforced by Singular. This is the
> largest positive value any degree can have before an overflow will occur. This
> internal bound may be higher than the bound requested by the user via the 
> `degree_bound` parameter of the `PolynomialRing` constructor.
"""
function degree_bound(R::PolyRing)
   return Int(libSingular.rBitmask(R.ptr))
end

zero(R::PolyRing) = R()

one(R::PolyRing) = R(1)

iszero(p::spoly) = p.ptr.cpp_object == C_NULL

function isone(p::spoly)
   return Bool(libSingular.p_IsOne(p.ptr, parent(p).ptr))
end

function isgen(p::spoly)
   R = parent(p)
   if p.ptr.cpp_object == C_NULL || libSingular.pNext(p.ptr).cpp_object != C_NULL || 
     !Bool(libSingular.n_IsOne(libSingular.pGetCoeff(p.ptr), base_ring(p).ptr))
      return false
   end
    n = 0
   for i = 1:ngens(R)
      d = libSingular.p_GetExp(p.ptr, Cint(i), R.ptr)
      if d > 1
         return false
      elseif d == 1
         if n == 1
            return false
         end
         n = 1
      end
   end
   return n == 1    
end

function isconstant(p::spoly)
   R = parent(p)
   if p.ptr.cpp_object == C_NULL
      return true
   end
   if libSingular.pNext(p.ptr).cpp_object != C_NULL
      return false
   end
   for i = 1:ngens(R)
      if libSingular.p_GetExp(p.ptr, Cint(i), R.ptr) != 0
         return false
      end
   end
   return true   
end

function isunit(p::spoly)
   return p.ptr.cpp_object != C_NULL && libSingular.pNext(p.ptr).cpp_object == C_NULL &&
          Bool(libSingular.p_IsUnit(p.ptr, parent(p).ptr))
end

length(p::spoly) = Int(libSingular.pLength(p.ptr))

function coeff(p::spoly, i::Int)
   i = length(p) - i - 1
   R = base_ring(p)
   if i < 0 || iszero(p)
      return R()
   end
   ptr = p.ptr
   for i = 1:i
      ptr = libSingular.pNext(ptr)
      if ptr.cpp_object == C_NULL
         return R()
      end
   end
   return R(libSingular.n_Copy(libSingular.pGetCoeff(ptr), R.ptr))
end

function exponent(p::spoly, i::Int)
   i = length(p) - i - 1
   R = parent(p)
   n = ngens(R)
   if i < 0 || iszero(p)
      return zeros(Int, n)
   end
   ptr = p.ptr
   for i = 1:i
      ptr = libSingular.pNext(ptr)
      if ptr.cpp_object == C_NULL
         return zeros(Int, n)
      end
   end
   A = Array{Int}(undef, n)
   libSingular.p_GetExpVL(ptr, A, R.ptr)
   return A
end

function exponent!(A::Array{Int, 1}, p::spoly, j::Int)
   i = length(p) - j - 1
   R = parent(p)
   n = ngens(R)
   @assert length(A) == n
   if i < 0 || iszero(p)
      for l=1:n
        A[l] = 0
      end
      return A
   end
   ptr = p.ptr
   for k = 1:i
      ptr = libSingular.pNext(ptr)
      if ptr.cpp_object == C_NULL
        for l=1:n
          A[l] = 0
        end
      end
   end
   libSingular.p_GetExpVL(ptr, A, R.ptr)
   return A
end

function degree(p::spoly)
   R = parent(p)
   libSingular.pLDeg(p.ptr, R.ptr)
end

mutable struct coeffs_expos
  E::Array{Int, 1}
  c::Nemo.RingElem
  R::Nemo.Ring
  Rx::Nemo.Ring
  a::spoly
  function coeffs_expos(p::spoly)
    r = new()
    Rx = parent(p)
    n = ngens(Rx)
    r.E = zeros(Int, n)
    r.Rx = Rx
    r.R = base_ring(p)
    r.c = r.R(0)
    r.a = p
    return r
  end
end

function show(io::IO, sp::coeffs_expos)
  println(io, "Coefficients and exponent iterator for $(sp.a)")
end

function Base.iterate(sp::coeffs_expos, p = sp.a.ptr)
  if p.cpp_object == C_NULL
    return nothing
  end
  libSingular.p_GetExpVL(p, sp.E, sp.Rx.ptr)
  sp.c = sp.R(libSingular.n_Copy(libSingular.pGetCoeff(p), sp.R.ptr))
  return ((sp.c, sp.E), libSingular.pNext(p))
end

@doc Markdown.doc"""
    lead_exponent(p::spoly)
> Return the exponent vector of the leading term of the given polynomial. The return
> value is a Julia 1-dimensional array giving the exponent for each variable of the
> leading term.
"""
function lead_exponent(p::spoly)
   R = parent(p)
   n = ngens(R)
   A = Array{Int}(undef, n)
   libSingular.p_GetExpVL(p.ptr, A, R.ptr)
   return A
end

function deepcopy_internal(p::spoly, dict::IdDict)
   p2 = libSingular.p_Copy(p.ptr, parent(p).ptr)
   return parent(p)(p2)
end

function check_parent(a::spoly{T}, b::spoly{T}) where T <: Nemo.RingElem
   parent(a) != parent(b) && error("Incompatible parent objects")
end

function canonical_unit(a::spoly{T}) where T <: Nemo.RingElem
  return a == 0 ? one(base_ring(a)) : canonical_unit(coeff(a, 0))
end
   
###############################################################################
#
#   String I/O
#
###############################################################################

function show(io::IO, R::PolyRing)
   s = libSingular.rString(R.ptr)
  #  s = unsafe_string(m)
  #  libSingular.omFree(Ptr{Nothing}(m))
   print(io, "Singular Polynomial Ring ", s)
end

function show(io::IO, a::spoly)
   s = libSingular.p_String(a.ptr, parent(a).ptr)
  #  s = unsafe_string(m)
  #  libSingular.omFree(Ptr{Nothing}(m))
   print(io, s)
end

show_minus_one(::Type{spoly{T}}) where T <: Nemo.RingElem = show_minus_one(T)

needs_parentheses(x::spoly) = length(x) > 1

isnegative(x::spoly) = isconstant(x) && !iszero(x) && isnegative(coeff(x, 0))

###############################################################################
#
#   Unary functions
#
###############################################################################

function -(a::spoly)
   a1 = libSingular.p_Copy(a.ptr, parent(a).ptr)
   s = libSingular.p_Neg(a1, parent(a).ptr)
   return parent(a)(s) 
end

###############################################################################
#
#   Arithmetic functions
#
###############################################################################

function (a::spoly{T} + b::spoly{T}) where T <: Nemo.RingElem
   check_parent(a, b)
   a1 = libSingular.p_Copy(a.ptr, parent(a).ptr)
   b1 = libSingular.p_Copy(b.ptr, parent(a).ptr)
   s = libSingular.p_Add_q(a1, b1, parent(a).ptr)
   return parent(a)(s) 
end

function (a::spoly{T} - b::spoly{T}) where T <: Nemo.RingElem
   check_parent(a, b)
   a1 = libSingular.p_Copy(a.ptr, parent(a).ptr)
   b1 = libSingular.p_Copy(b.ptr, parent(a).ptr)
   s = libSingular.p_Sub(a1, b1, parent(a).ptr)
   return parent(a)(s) 
end

function (a::spoly{T} * b::spoly{T}) where T <: Nemo.RingElem
   check_parent(a, b)
   a1 = libSingular.p_Copy(a.ptr, parent(a).ptr)
   b1 = libSingular.p_Copy(b.ptr, parent(a).ptr)
   s = libSingular.p_Mult_q(a1, b1, parent(a).ptr)
   return parent(a)(s) 
end

###############################################################################
#
#   Powering
#
###############################################################################

function ^(x::spoly, y::Int)
    y > typemax(Cint) || y < typemin(Cint) && throw(DomainError())
    R = parent(x)
    if isone(x)
       return deepcopy(x)
    elseif y == 0
       return one(R)
    elseif y == 1
       return deepcopy(x)
    end
    x1 = libSingular.p_Copy(x.ptr, R.ptr)
    p = libSingular.p_Power(x1, Cint(y), R.ptr)
    return R(p)
end

###############################################################################
#
#   Comparison
#
###############################################################################

function (x::spoly{T} == y::spoly{T}) where T <: Nemo.RingElem
    check_parent(x, y)
    return Bool(libSingular.p_EqualPolys(x.ptr, y.ptr, parent(x).ptr))
end

###############################################################################
#
#   Exact division
#
###############################################################################

function divexact(x::spoly, y::spoly)
   check_parent(x, y)
   R = parent(x)
   x1 = libSingular.p_Copy(x.ptr, R.ptr)
   y1 = libSingular.p_Copy(y.ptr, R.ptr)
   p = libSingular.p_Divide(x1, y1, R.ptr)
   return R(p)
end

###############################################################################
#
#   GCD
#
###############################################################################

function gcd(x::spoly{T}, y::spoly{T}) where T <: Nemo.RingElem
   check_parent(x, y)
   R = parent(x)   
   x1 = libSingular.p_Copy(x.ptr, R.ptr)   
   y1 = libSingular.p_Copy(y.ptr, R.ptr)
   p = libSingular.singclap_gcd(x1, y1, R.ptr)
   return R(p)
end

function gcdx(x::spoly{T}, y::spoly{T}) where T <: Nemo.FieldElem
   check_parent(x, y)
   R = parent(x)
   x1 = libSingular.p_Copy(x.ptr, R.ptr)
   y1 = libSingular.p_Copy(y.ptr, R.ptr)
   s = [libSingular.p_ISet(0,R.ptr)]
   t = [libSingular.p_ISet(0,R.ptr)]
   p = [libSingular.p_ISet(0,R.ptr)]
   libSingular.p_ExtGcd(x1, y1, pointer(p), pointer(s), pointer(t), R.ptr)
   return R(p[]), R(s[]), R(t[])
end

function lcm(x::spoly{T}, y::spoly{T}) where T <: Nemo.RingElem
   if iszero(x) && iszero(y)
      return parent(x)()
   end
   return divexact(x*y, gcd(x, y))
end

@doc Markdown.doc"""
    primpart(x::spoly)
> Return the primitive part of the polynomial, i.e. the polynomial divided by the GCD
> of its coefficients.
"""
function primpart(x::spoly)
   R = parent(x)
   p = deepcopy(x)
   libSingular.p_Content(p.ptr, R.ptr)
   return p
end

@doc Markdown.doc"""
    content(x::spoly)
> Return the content of the polynomial, i.e. the GCD of its coefficients.
"""
function content(x::spoly)
   R = base_ring(x)
   d = R()
   for i = 1:length(x)
      d = gcd(d, coeff(x, i - 1))
      if isone(d)
         break
      end
   end
   return d
end

###############################################################################
#
#   Unsafe operations
#
###############################################################################

function addeq!(x::spoly, y::spoly)
    R = parent(x)
    if y.ptr == C_NULL
    elseif x.ptr == C_NULL
       x.ptr = libSingular.p_Copy(y.ptr, R.ptr)
    else
       x.ptr = libSingular.p_Add_q(x.ptr, libSingular.p_Copy(y.ptr, R.ptr), R.ptr)
    end
    return x
end

function mul!(c::spoly, x::spoly, y::spoly) 
   R = parent(x)
   x1 = libSingular.p_Copy(x.ptr, R.ptr)
   y1 = libSingular.p_Copy(y.ptr, R.ptr)
   ptr = libSingular.p_Mult_q(x1, y1, R.ptr)
   if c.ptr != C_NULL
      libSingular.p_Delete(c.ptr, R.ptr)
   end
   c.ptr = ptr
   return c
end

function add!(c::spoly, x::spoly, y::spoly) 
   R = parent(x)
   x1 = libSingular.p_Copy(x.ptr, R.ptr)
   y1 = libSingular.p_Copy(y.ptr, R.ptr)
   ptr = libSingular.p_Add_q(x1, y1, R.ptr)
   if c.ptr != C_NULL
      libSingular.p_Delete(c.ptr, R.ptr)
   end
   c.ptr = ptr
   return c
end

function zero!(x::spoly)
   if x.ptr != C_NULL
      libSingular.p_Delete(x.ptr, parent(x).ptr)
      x.ptr = libSingular.p_ISet(0, parent(x).ptr)
   end
   return x
end

###############################################################################
#
#   Promote rules
#
###############################################################################

promote_rule(::Type{spoly{T}}, ::Type{spoly{T}}) where T <: Nemo.RingElem = spoly{T}

function promote_rule(::Type{spoly{T}}, ::Type{U}) where {T <: Nemo.RingElem, U <: Nemo.RingElem}
   promote_rule(T, U) == T ? spoly{T} : Union{}
end

###############################################################################
#
#   Parent call overloads
#
###############################################################################

function (R::PolyRing)()
   T = elem_type(base_ring(R))
   z = spoly{T}(R)
   z.parent = R
   return z
end

function (R::PolyRing)(n::Int)
   T = elem_type(base_ring(R))
   z = spoly{T}(R, n)
   z.parent = R
   return z
end

function (R::PolyRing)(n::Integer)
   T = elem_type(base_ring(R))
   z = spoly{T}(R, BigInt(n))
   z.parent = R
   return z
end

function (R::PolyRing)(n::n_Z)
   n = base_ring(R)(n)
   ptr = libSingular.n_Copy(n.ptr, parent(n).ptr)
   T = elem_type(base_ring(R))
   z = spoly{T}(R, ptr)
   z.parent = R
   return z
end

function (R::PolyRing)(n::libSingular.poly)
   T = elem_type(base_ring(R))
   z = spoly{T}(R, n)
   z.parent = R
   return z
end

function (R::PolyRing{T})(n::T) where T <: Nemo.RingElem
   parent(n) != base_ring(R) && error("Unable to coerce into polynomial ring")
   z = spoly{T}(R, n.ptr)
   z.parent = R
   return z
end

function (R::PolyRing{S})(n::T) where {S <: Nemo.RingElem, T <: Nemo.RingElem} 
   return R(base_ring(R)(n))   
end

function (R::PolyRing)(p::spoly)
   parent(p) != R && error("Unable to coerce polynomial")
   return p
end

###############################################################################
#
#   PolynomialRing constructor
#
###############################################################################

function PolynomialRing(R::Union{Ring, Field}, s::Array{String, 1};
      cached::Bool = true, ordering::Symbol = :degrevlex,
      ordering2::Symbol = :comp1min, degree_bound::Int = 0)
   U = [Symbol(v) for v in s]
   T = elem_type(R)
   parent_obj = PolyRing{T}(R, U, cached, sym2ringorder[ordering],
         sym2ringorder[ordering2], degree_bound)
   return tuple(parent_obj, gens(parent_obj))
end

function PolynomialRing(R::Nemo.Ring, s::Array{String, 1}; cached::Bool = true,
      ordering::Symbol = :degrevlex, ordering2::Symbol = :comp1min,
      degree_bound::Int = 0)
   S = CoefficientRing(R)
   U = [Symbol(v) for v in s]
   T = elem_type(S)
   parent_obj = PolyRing{T}(S, U, cached, sym2ringorder[ordering],
         sym2ringorder[ordering2], degree_bound)
   return tuple(parent_obj, gens(parent_obj))
end

macro PolynomialRing(R, s, n, o)
   S = gensym()
   y = gensym()
   v0 = [s*string(i) for i in 1:n]
   exp1 = :(($S, $y) = PolynomialRing($R, $v0; ordering=$o))
   v = [:($(Symbol(s, i)) = $y[$i]) for i in 1:n]
   v1 = Expr(:block, exp1, v..., S)
   return esc(v1)
end

macro PolynomialRing(R, s, n)
   S = gensym()
   y = gensym()
   v0 = [s*string(i) for i in 1:n]
   exp1 = :(($S, $y) = PolynomialRing($R, $v0))
   v = [:($(Symbol(s, i)) = $y[$i]) for i in 1:n]
   v1 = Expr(:block, exp1, v..., S)
   return esc(v1)
end

###############################################################################
#
#   Conversion functions
#
###############################################################################

@doc Markdown.doc"""
    AsEquivalentSingularPolynomialRing(R::AbstractAlgebra.Generic.MPolyRing{T}; cached::Bool = true,
      ordering::Symbol = :degrevlex, ordering2::Symbol = :comp1min,
      degree_bound::Int = 0)  where {T <: RingElem}
> Return a Singular (multivariate) polynomial ring over the base ring of $R$ in variables having the same names as those of R.
"""
function AsEquivalentSingularPolynomialRing(R::AbstractAlgebra.Generic.MPolyRing{T}; cached::Bool = true,
      ordering::Symbol = :degrevlex, ordering2::Symbol = :comp1min,
      degree_bound::Int = 0)  where {T <: RingElem}
   return PolynomialRing(AbstractAlgebra.Generic.base_ring(R), [string(v) for v in AbstractAlgebra.Generic.symbols(R)], cached=cached, ordering=ordering, ordering2=ordering2, degree_bound=degree_bound)
end

@doc Markdown.doc"""
    AsEquivalentAbstractAlgebraPolynomialRing(R::Singular.PolyRing{Singular.n_unknown{T}}; ordering::Symbol = :degrevlex)  where {T <: RingElem}
> Return an AbstractAlgebra (multivariate) polynomial ring over the base ring of $R$ in variables having the same names as those of R.
"""
function AsEquivalentAbstractAlgebraPolynomialRing(R::Singular.PolyRing{Singular.n_unknown{T}}; ordering::Symbol = :degrevlex)  where {T <: RingElem}
   return AbstractAlgebra.Generic.PolynomialRing(base_ring(R).base_ring, Base.convert( Array{String,1}, symbols(R)), ordering=ordering)
end


@doc Markdown.doc"""
    (R::PolyRing){T <: RingElem}(p::AbstractAlgebra.Generic.MPoly{T})
> Return a Singular polynomial in $R$ with the same coefficients and exponents as $p$.
"""
function (R::PolyRing)(p::AbstractAlgebra.Generic.MPoly{T}) where T <: Nemo.RingElem
   parent_ring = parent(p)
   n = nvars(parent_ring)
   exps = p.exps

   size_exps = size(p.exps)
   if parent_ring.ord != :lex
      exps = exps[2:size_exps[1],:]
   end
   if parent_ring.ord == :degrevlex
      exps = exps[end:-1:1,:]
   end

   new_p = zero(R)

   for i=1:length(p)
      prod = p.coeffs[i]
      for j=1:n
         prod = prod * gens(R)[j]^Int(exps[j,i])
      end
      new_p = new_p + prod
   end
   return(new_p)
end

@doc Markdown.doc"""
   (R::AbstractAlgebra.Generic.MPolyRing{T}){T <: Nemo.RingElem}(p::Singular.spoly{Singular.n_unknown{T}})
> Return a AbstractAlgebra polynomial in R with the same coefficients and exponents as $p$.
"""
function (R::AbstractAlgebra.Generic.MPolyRing{T})(p::Singular.spoly{Singular.n_unknown{T}}) where T <: Nemo.RingElem
   parent_ring = parent(p)
   n = ngens(parent_ring)
   new_p = zero(R)
   gens = AbstractAlgebra.Generic.gens(R)
   iterator = coeffs_expos(p)
   t = start(iterator)
   while !done(iterator,t)
      (coeff,exps),t = next(iterator,t)
      new_p = new_p + libSingular.julia(coeff.ptr) * prod(gens.^exps)
   end
   return(new_p)
end
