public final class Extension<Base> {
  let base: Base
  public init(_ base: Base) {
    self.base = base
  }
}

public protocol ExtensionCompatible {
  associatedtype CompatibleType
  var ex: CompatibleType { get }
}

public extension ExtensionCompatible {
  var ex: Extension<Self> {
    return Extension(self)
  }
}
