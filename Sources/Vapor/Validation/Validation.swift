extension String: ErrorProtocol {}

// MARK: Testing

extension Validatable {
    public func tested(@noescape by tester: (input: Self) throws -> Bool) throws -> Self {
        guard try tester(input: self) else { throw "up" }
        return self
    }

    public func tested<V: Validator where V.InputType == Self>(by tester: V) throws -> Self {
        return try tested(by: tester.test)
    }

    public func tested<S: ValidationSuite where S.InputType == Self>(by tester: S.Type) throws -> Self {
        return try tested(by: tester.test)
    }

}

extension Optional where Wrapped: Validatable {
    public func tested(@noescape by tester: (input: Wrapped) throws -> Bool) throws -> Wrapped {
        guard case .some(let value) = self else { throw "error" }
        return try value.tested(by: tester)
    }

    public func tested<V: Validator where V.InputType == Wrapped>(by validator: V) throws -> Wrapped {
        return try tested(by: validator.test)
    }

    public func tested<S: ValidationSuite where S.InputType == Wrapped>(by suite: S.Type) throws -> Wrapped {
        return try tested(by: suite.test)
    }
}

// MARK: Validation

extension Validatable {
    public func validated<V: Validator where V.InputType == Self>(by validator: V) throws -> Validated<V> {
        return try Validated<V>(self, by: validator)
    }
    public func validated<S: ValidationSuite where S.InputType == Self>(by type: S.Type = S.self) throws -> Validated<S> {
        return try Validated<S>(self, by: S.self)
    }
}

extension Optional where Wrapped: Validatable {
    public func validated<V: Validator where V.InputType == Wrapped>(by validator: V) throws -> Validated<V> {
        guard case .some(let value) = self else { throw "error" }
        return try Validated<V>(value, by: validator)
    }
    public func validated<S: ValidationSuite where S.InputType == Wrapped>(by type: S.Type = S.self) throws -> Validated<S> {
        guard case .some(let value) = self else { throw "error" }
        return try Validated<S>(value, by: S.self)
    }
}


/*
 Possible Naming Conventions

 validated by Tester -> Verified<T: Tester>
 validated by TestSuite -> Verified<T: TestSuite>

 tested by (Self -> Bool) -> Self
 tested by Tester -> Self
 tested by TestSuite -> Self
 */

// MARK: Validators

public protocol Validator {
    associatedtype InputType: Validatable
    func test(input value: InputType) -> Bool
}

public protocol ValidationSuite: Validator {
    associatedtype InputType: Validatable
    static func test(input value: InputType) -> Bool
}

extension ValidationSuite {
    public func test(input value: InputType) -> Bool {
        return self.dynamicType.test(input: value)
    }
}

// MARK: Operators

public prefix func ! <V: Validator> (rhs: V) -> Not<V> {
    return Not(rhs)
}
public prefix func ! <V: ValidationSuite> (rhs: V.Type) -> Not<V> {
    return Not(rhs)
}

public func || <V: Validator, U: Validator where V.InputType == U.InputType> (lhs: V, rhs: U) -> Or<V, U> {
    return Or(lhs, rhs)
}

public func || <V: Validator, U: ValidationSuite where V.InputType == U.InputType> (lhs: V, rhs: U.Type) -> Or<V, U> {
    return Or(lhs, rhs)
}

public func || <V: ValidationSuite, U: Validator where V.InputType == U.InputType> (lhs: V.Type, rhs: U) -> Or<V, U> {
    return Or(lhs, rhs)
}

public func || <V: ValidationSuite, U: ValidationSuite where V.InputType == U.InputType> (lhs: V.Type, rhs: U.Type) -> Or<V, U> {
    return Or(lhs, rhs)
}

public func && <V: Validator, U: Validator where V.InputType == U.InputType> (lhs: V, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

public func && <V: Validator, U: ValidationSuite where V.InputType == U.InputType> (lhs: V, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

public func && <V: ValidationSuite, U: Validator where V.InputType == U.InputType> (lhs: V.Type, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

public func && <V: ValidationSuite, U: ValidationSuite where V.InputType == U.InputType> (lhs: V.Type, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

public func + <V: Validator, U: Validator where V.InputType == U.InputType>(lhs: V, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

public func + <V: Validator, U: ValidationSuite where V.InputType == U.InputType>(lhs: V, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

public func + <V: ValidationSuite, U: Validator where V.InputType == U.InputType>(lhs: V.Type, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

public func + <V: ValidationSuite, U: ValidationSuite where V.InputType == U.InputType>(lhs: V.Type, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

// MARK: Validated

public struct Validated<V: Validator> {
    public let value: V.InputType

    public init(_ value: V.InputType, by validator: V) throws {
        try self.value = value.tested(by: validator)
    }
}

extension Validated where V: ValidationSuite {
    public init(_ value: V.InputType, by suite: V.Type = V.self) throws {
        try self.value = value.tested(by: suite)
    }
}

class ContainsEmoji: ValidationSuite {
    static func test(input value: String) -> Bool {
        return true
    }
}
class AlreadyTaken: ValidationSuite {
    static func test(input value: String) -> Bool {
        return true
    }
}
class OwnedBy: Validator {
    init(user: String) {}
    func test(input value: String) -> Bool {
        return true
    }
}

let user = ""

let available = !AlreadyTaken.self || OwnedBy(user: user)
let appropriateLength = StringLength.min(5) + StringLength.max(20)
let blename = try! "new name".validated(by: !ContainsEmoji.self + appropriateLength + available)

// MARK: And

public struct And<
    V: Validator,
    U: Validator where V.InputType == U.InputType> {
    private typealias Closure = (input: V.InputType) -> Bool
    private let _test: Closure

    /**
     CONVENIENCE ONLY.

     MUST STAY PRIVATE
     */
    private init(_ lhs: Closure, _ rhs: Closure) {
        _test = { value in
            return lhs(input: value) && rhs(input: value)
        }
    }
}

extension And {
    public init(_ lhs: V, _ rhs: U) {
        self.init(lhs.test, rhs.test)
    }
}

extension And: Validator {
    public func test(input value: V.InputType) -> Bool {
        return _test(input: value)
    }
}

extension And where V: ValidationSuite {
    public init(_ lhs: V.Type = V.self, _ rhs: U) {
        self.init(lhs.test, rhs.test)
    }
}

extension And where U: ValidationSuite {
    public init(_ lhs: V, _ rhs: U.Type = U.self) {
        self.init(lhs.test, rhs.test)
    }
}

extension And where V: ValidationSuite, U: ValidationSuite {
    public init(_ lhs: V.Type = V.self, _ rhs: U.Type = U.self) {
        self.init(lhs.test, rhs.test)
    }
}

// MARK: Or

public struct Or<
    V: Validator,
    U: Validator where V.InputType == U.InputType> {

    private typealias Closure = (input: V.InputType) -> Bool
    private let _test: Closure

    /**
     CONVENIENCE ONLY.
     
     MUST STAY PRIVATE
     */
    private init(_ lhs: Closure, _ rhs: Closure) {
        _test = { value in
            return lhs(input: value) || rhs(input: value)
        }
    }
}

extension Or: Validator {
    public func test(input value: V.InputType) -> Bool {
        return _test(input: value)
    }
}

extension Or {
    public init(_ lhs: V, _ rhs: U) {
        self.init(lhs.test, rhs.test)
    }
}

extension Or where V: ValidationSuite {
    public init(_ lhs: V.Type = V.self, _ rhs: U) {
        self.init(lhs.test, rhs.test)
    }
}

extension Or where U: ValidationSuite {
    public init(_ lhs: V, _ rhs: U.Type = U.self) {
        self.init(lhs.test, rhs.test)
    }
}

extension Or where V: ValidationSuite, U: ValidationSuite {
    public init(_ lhs: V.Type = V.self, _ rhs: U.Type = U.self) {
        self.init(lhs.test, rhs.test)
    }
}

// MARK: Not

public struct Not<V: Validator> {
    private typealias Closure = (input: V.InputType) -> Bool
    private let _test: Closure

    /**
     CONVENIENCE ONLY.

     MUST STAY PRIVATE
     */
    private init(_ v1: Closure) {
        _test = { value in !v1(input: value) }
    }
}

extension Not: Validator {
    public func test(input value: V.InputType) -> Bool {
        return _test(input: value)
    }
}

extension Not {
    public init(_ lhs: V) {
        self.init(lhs.test)
    }
}


extension Not where V: ValidationSuite {
    public init(_ lhs: V.Type = V.self) {
        self.init(lhs.test)
    }
}

// MARK: Composition
