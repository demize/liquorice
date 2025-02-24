const std = @import("std");
const zul = @import("zul");

pub const AppToken = struct {
    clientId: []const u8,
    clientSecret: []const u8,
    accessToken: []u8,
    expiresIn: u32,
    obtained: zul.DateTime,

    pub fn jsonStringify(self: *const AppToken, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("accessToken");
        try jws.write(self.accessToken);
        try jws.objectField("expiresIn");
        try jws.write(self.expiresIn);
        try jws.objectField("obtained");
        try jws.write(self.obtained);
        try jws.endObject();
    }
};

pub const UserToken = struct {
    accessToken: []u8,
    refreshToken: []u8,
    scopes: [][]u8,
    expiresIn: u32,
    obtained: zul.DateTime,

    pub fn jsonStringify(self: *const UserToken, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("accessToken");
        try jws.write(self.accessToken);
        try jws.objectField("refreshToken");
        try jws.write(self.refreshToken);
        try jws.objectField("scopes");
        try jws.write(self.scopes);
        try jws.objectField("expiresIn");
        try jws.write(self.expiresIn);
        try jws.objectField("obtained");
        try jws.write(self.obtained);
        try jws.endObject();
    }
};
