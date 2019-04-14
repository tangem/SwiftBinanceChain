import Foundation
import SwiftProtobuf
import SwiftyJSON

public class Message {

    private enum MessageType: String {
        case newOrder = "CE6DC043"
        case cancelOrder = "166E681B"
        case freeze = "E774B32D"
        case unfreeze = "6515FF0D"
        case transfer = "2A2C87FA"
        case vote = "A1CADD36"
        case stdtx = "F0625DEE"
        case signature = ""
        case publicKey = "EB5AE987"
    }

    private enum Source: Int {
        case hidden = 0
        case broadcast = 1
    }

    private var type: MessageType = .newOrder
    private var wallet: Wallet
    private var symbol: String = ""
    private var orderId: String = ""
    private var orderType: OrderType = .limit
    private var side: Side = .buy
    private var price: Double = 0
    private var amount: Double = 0
    private var quantity: Double = 0
    private var timeInForce: TimeInForce = .goodTillExpire
    private var data: Data = Data()
    private var memo: String = ""
    private var toAddress: String = ""
    private var proposalId: Int = 0
    private var voteOption: VoteOption = .no

    // MARK: - Constructors

    private init(type: MessageType, wallet: Wallet) {
        self.type = type
        self.wallet = wallet
    }

    public static func newOrder(symbol: String, orderType: OrderType, side: Side, price: Double, quantity: Double, timeInForce: TimeInForce, wallet: Wallet) -> Message {
        let message = Message(type: .newOrder, wallet: wallet)
        message.orderType = orderType
        message.side = side
        message.price = price
        message.quantity = quantity
        message.timeInForce = timeInForce
        return message
    }

    public static func cancelOrder(symbol: String, orderId: String, wallet: Wallet) -> Message {
        let message = Message(type: .cancelOrder, wallet: wallet)
        message.symbol = symbol
        message.orderId = orderId
        return message
    }

    public static func freeze(symbol: String, amount: Double, wallet: Wallet) -> Message  {
        let message = Message(type: .freeze, wallet: wallet)
        message.symbol = symbol
        message.amount = amount
        return message
    }

    public static func unfreeze(symbol: String, amount: Double, wallet: Wallet) -> Message  {
        let message = Message(type: .unfreeze, wallet: wallet)
        message.symbol = symbol
        message.amount = amount
        return message
    }

    public static func transfer(symbol: String, amount: Double, toAddress: String, wallet: Wallet) -> Message {
        let message = Message(type: .transfer, wallet: wallet)
        message.symbol = symbol
        message.amount = amount
        message.toAddress = toAddress
        return message
    }

    public static func vote(proposalId: Int, vote option: VoteOption, wallet: Wallet) -> Message {
        let message = Message(type: .cancelOrder, wallet: wallet)
        message.proposalId = proposalId
        message.voteOption = option
        return message
    }

    // MARK: - Public

    public func encode() throws -> Data {
        
        // Generate encoded message
        var message = Data()
        let body = try self.body(type: self.type)
        message.append(body.varint)
        message.append(self.type.rawValue.unhexlify)
        message.append(body)

        // Generate signature
        let signature = try self.body(type: .signature)
        
        // Wrap in StdTx structure
        var stdtx = StdTx()
        stdtx.msgs.append(message)
        stdtx.signatures.append(signature)
        stdtx.memo = self.memo
        stdtx.source = Int64(Source.broadcast.rawValue)
        stdtx.data = Data()

        // Prefix length and stdtx type
        var content = Data()
        content.append(MessageType.stdtx.rawValue.unhexlify)
        content.append(try stdtx.serializedData())
        
        // Complete Standard Transaction
        var transaction = Data()
        transaction.append(content.varint)
        transaction.append(content)
        return transaction

    }
    
    // MARK: - Private

    private func body(type: MessageType) throws -> Data {

        switch (self.type) {

        case .newOrder:
            var pb = NewOrder()
            pb.sender = self.wallet.address.unhexlify // TODO  - address from public key, for environment (hrp: bnb or tbnb)
            pb.id = self.wallet.orderId
            pb.symbol = symbol
            pb.timeinforce = Int64(self.timeInForce.rawValue)
            pb.ordertype = Int64(self.orderType.rawValue)
            pb.side = Int64(self.side.rawValue)
            pb.price = Int64(price)
            pb.quantity = Int64(quantity)
            return try pb.serializedData()

        case .cancelOrder:
            var pb = CancelOrder()
            pb.symbol = symbol
            pb.refid = self.orderId
            return try! pb.serializedData()

        case .freeze:
            var pb = TokenFreeze()
            pb.symbol = symbol
            pb.amount = Int64(self.amount)
            return try pb.serializedData()

        case .unfreeze:
            var pb = TokenUnfreeze()
            pb.symbol = symbol
            pb.amount = Int64(self.amount)
            return try pb.serializedData()

        case .transfer:
            var token = Send.Token()
            token.denom = self.symbol
            token.amount = Int64(amount)

            var input = Send.Input()
            //input.address = Segwit.decode(address: self.wallet.address)
            input.coins.append(token)
            
            var output = Send.Output()
            //output.address = Segwit.decode(address: to)
            output.coins.append(token)
            
            var send = Send()
            send.inputs.append(input)
            send.outputs.append(output)
            return try send.serializedData()

        case .signature:
            var pb = StdSignature()
            pb.sequence = Int64(self.wallet.sequence)
            pb.accountNumber = Int64(self.wallet.accountNumber)
            pb.pubKey = try self.body(type: .publicKey)
            pb.signature = try self.signature()
            return try pb.serializedData()

        case .publicKey:
            let key = self.wallet.publicKey
            var data = Data()
            data.append(type.rawValue.unhexlify)
            data.append(key.varint)
            data.append(key)
            return data

        case .vote:
            var vote = Vote()
            vote.proposalID = Int64(self.proposalId)
            vote.voter = Data(self.wallet.address.utf8)
            vote.option = Int64(self.voteOption.rawValue)
            return try vote.serializedData()
            
        default:
            throw BinanceError(message: "Unavailable")

        }

    }

    private func signature() throws -> Data {
        guard let data = self.json().data(using: .utf8) else { throw BinanceError(message: "Invalid signature") }
        return self.wallet.sign(message: data)
    }

    private func json() -> String {
        // TODO
        return keyValuePairs().json
    }

    private func keyValuePairs() -> KeyValuePairs<String, Any> {

        switch (self.type) {
        case .newOrder:
            return [
                "id": self.wallet.orderId,
                "ordertype": self.orderType.rawValue,
                "price": self.price,
                "quantity": self.quantity,
                "side": self.side.rawValue,
                "symbol": self.symbol,
                "timeinforce": self.timeInForce.rawValue
            ]

        case .cancelOrder:
            return [
                "refid": self.orderId,
                "sender": self.wallet.address,
                "symbol": self.symbol
            ]

        case .freeze:
            return [
                "amount": self.amount,
                "from": self.wallet.address,
                "symbol": self.symbol
            ]
 
        case .unfreeze:
            return [
                "amount": self.amount,
                "from": self.wallet.address,
                "symbol": self.symbol
            ]

        case .transfer:
            return [
                "inputs": [ self.accountKeyValuePair(address: self.wallet.address, symbol: symbol, amount: amount) ],
                "outputs": [ self.accountKeyValuePair(address: toAddress, symbol: symbol, amount: amount) ]
            ]

        case .publicKey:
            return  [
                "amount": amount,
                "denom": symbol
            ]

        case .vote:
            return [
                "proposal_id": Int64(self.proposalId),
                "voter": self.wallet.address,
                "option": UInt64(self.voteOption.rawValue)
            ]
            
        default:
            return [:]

        }

    }

    private func accountKeyValuePair(address: String, symbol: String, amount: Double) -> KeyValuePairs<String, Any> {
        return [
            "address": address,
            "coins": self.moneyKeyValuePair(symbol: symbol, amount: amount)
        ]
    }

    private func moneyKeyValuePair(symbol: String, amount: Double) -> KeyValuePairs<String, Any> {
        return  [
            "amount": amount,
            "denom": symbol
        ]
    }
    
}

extension Data {
    var varint: UInt8 {
        return UInt8(Varint.encodedSize(of: UInt32(self.count)))
    }
}