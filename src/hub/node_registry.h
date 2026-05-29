// =============================================================================
//  node_registry.h  --  List of trusted sensor nodes known to the hub
// -----------------------------------------------------------------------------
//  The hub only trusts packets coming from a MAC listed here. When ESP-NOW
//  encryption is enabled, every node must also be added as an encrypted peer,
//  which requires its MAC up front -- so this table is the single source of
//  truth for "which rooms exist".
//
//  HOW TO FILL THIS IN:
//    1. Flash each sensor node. At boot it prints its STA MAC, e.g.
//         [BOOT] Node STA MAC: 24:6F:28:10:00:02
//    2. Copy that MAC (and its room) into a row below.
//    3. Re-flash the hub.
//
//  Up to MAX_ROOMS entries are supported.
// =============================================================================
#pragma once
#include <stddef.h>
#include <stdint.h>

struct NodeEntry {
  uint8_t     roomId;     // must match the node's -DROOM_ID
  const char *name;       // short label shown on the LCD / SMS (<=12 chars)
  uint8_t     mac[6];     // node STA MAC address
};

// ---- EDIT THESE ROWS to match your deployment ------------------------------
static const NodeEntry NODE_REGISTRY[] = {
    {1, "Living Room", {0x24, 0x6F, 0x28, 0x10, 0x00, 0x01}},
    {2, "Kitchen",     {0x24, 0x6F, 0x28, 0x10, 0x00, 0x02}},
    {3, "Bedroom",     {0x24, 0x6F, 0x28, 0x10, 0x00, 0x03}},
};

static const size_t NODE_REGISTRY_COUNT =
    sizeof(NODE_REGISTRY) / sizeof(NODE_REGISTRY[0]);

// Returns the registry index for a MAC, or -1 if the sender is unknown.
static inline int registryIndexForMac(const uint8_t *mac) {
  for (size_t i = 0; i < NODE_REGISTRY_COUNT; ++i) {
    bool match = true;
    for (uint8_t b = 0; b < 6; ++b) {
      if (NODE_REGISTRY[i].mac[b] != mac[b]) {
        match = false;
        break;
      }
    }
    if (match) return (int)i;
  }
  return -1;
}

// Returns a human-readable room name for a roomId (or "Unknown").
static inline const char *roomNameForId(uint8_t roomId) {
  for (size_t i = 0; i < NODE_REGISTRY_COUNT; ++i) {
    if (NODE_REGISTRY[i].roomId == roomId) return NODE_REGISTRY[i].name;
  }
  return "Unknown";
}
