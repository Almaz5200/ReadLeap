//
//  OptionalType.swift
//  Etalon2.0
//
//  Created by Artem Trubacheev on 23/08/2019.
//  Copyright © 2019 Tribuna Digital. All rights reserved.
//

public protocol NilableType {
    associatedtype Wrapped

    static var empty: Self { get }
}

extension Optional: NilableType {

    public static var empty: Wrapped? { nil }

}
