// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Testnet 2048: pay a fee to play, save score, unique wallet-bound names, top-20 board.
/// Scores are self-reported by the player (only loosely sanity-checked): fun/testnet use only.
contract Game2048 {
    struct G { address p; uint64 t; bool done; }
    struct E { address a; uint32 s; }

    address public owner;
    uint256 public fee;
    uint256 public nextId;
    mapping(uint256 => G) public games;
    mapping(address => string) public nameOf;
    mapping(bytes32 => address) public ownerOfName;
    mapping(address => uint32) public best;
    E[20] public top;

    event Started(uint256 indexed id, address indexed p);
    event Scored(address indexed p, uint32 s, uint256 indexed id);
    event Named(address indexed p, string n);

    constructor(uint256 f) { owner = msg.sender; fee = f; }

    function setFee(uint256 f) external { require(msg.sender == owner, "owner"); fee = f; }

    function withdraw() external {
        require(msg.sender == owner, "owner");
        (bool ok, ) = owner.call{value: address(this).balance}("");
        require(ok, "send");
    }

    function play() external payable returns (uint256 id) {
        require(msg.value >= fee, "fee");
        id = ++nextId;
        games[id] = G(msg.sender, uint64(block.timestamp), false);
        emit Started(id, msg.sender);
    }

    function submit(uint256 id, uint32 s) external {
        G storage g = games[id];
        require(g.p == msg.sender && !g.done, "bad game");
        require(s <= 4_000_000, "score");
        require(block.timestamp >= uint256(g.t) + s / 500, "too fast");
        g.done = true;
        emit Scored(msg.sender, s, id);
        if (s > best[msg.sender]) { best[msg.sender] = s; _rank(msg.sender, s); }
    }

    function _rank(address a, uint32 s) internal {
        uint256 i = 20;
        for (uint256 k = 0; k < 20; k++) { if (top[k].a == a) { i = k; break; } }
        if (i == 20) { if (s <= top[19].s) return; i = 19; top[19] = E(a, s); }
        else { top[i].s = s; }
        while (i > 0 && top[i].s > top[i - 1].s) { E memory t = top[i]; top[i] = top[i - 1]; top[i - 1] = t; i--; }
    }

    function setName(string calldata n) external {
        bytes memory b = bytes(n);
        require(b.length >= 3 && b.length <= 16, "length 3-16");
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            require((c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c == 0x5f, "a-z 0-9 _");
        }
        bytes32 h = keccak256(b);
        address cur = ownerOfName[h];
        require(cur == address(0) || cur == msg.sender, "taken");
        bytes memory old = bytes(nameOf[msg.sender]);
        if (old.length > 0) delete ownerOfName[keccak256(old)];
        ownerOfName[h] = msg.sender;
        nameOf[msg.sender] = n;
        emit Named(msg.sender, n);
    }

    function getTop() external view returns (address[] memory a, uint32[] memory s, string[] memory n) {
        a = new address[](20); s = new uint32[](20); n = new string[](20);
        for (uint256 i = 0; i < 20; i++) { a[i] = top[i].a; s[i] = top[i].s; n[i] = nameOf[top[i].a]; }
    }
}
