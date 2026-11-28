#include "window_state.h"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <string>

namespace {

constexpr int kSupportedVersion = 1;
constexpr int kDefaultDpi = 96;
constexpr int kMinDpi = 48;
constexpr int kMaxDpi = 960;
constexpr int kMaxCoord = 32768;
constexpr int kMinCoord = -32768;
constexpr int kMaxDimension = 32768;

// Minimum visible title-bar grab area in logical pixels.
constexpr int kMinVisibleTitleLogicalWidth = 120;
constexpr int kMinVisibleTopLogicalHeight = 48;
// Windows 10/11 DWM windows have ~7-8 logical px invisible resize borders on
// left, right, and bottom; allow a small tolerance so edge-snapped windows are
// not nudged away from screen edges on restore.
constexpr int kDwmBorderLogicalTolerance = 10;

int ScaleLogical(int logical, int dpi) {
  const int safe_dpi = dpi > 0 ? dpi : kDefaultDpi;
  return static_cast<int>(std::lround(logical * (safe_dpi / 96.0)));
}

int RescaleDimension(int value, int from_dpi, int to_dpi) {
  if (from_dpi <= 0 || to_dpi <= 0 || from_dpi == to_dpi) {
    return value;
  }
  return static_cast<int>(
      std::lround(static_cast<double>(value) * to_dpi / from_dpi));
}

int ClampInt(int value, int low, int high) {
  if (value < low) {
    return low;
  }
  if (value > high) {
    return high;
  }
  return value;
}

class JsonCursor {
 public:
  explicit JsonCursor(const std::string& input) : input_(input), pos_(0) {
    if (input_.size() >= 3 &&
        static_cast<unsigned char>(input_[0]) == 0xEF &&
        static_cast<unsigned char>(input_[1]) == 0xBB &&
        static_cast<unsigned char>(input_[2]) == 0xBF) {
      pos_ = 3;
    }
  }

  void SkipWhitespace() {
    while (pos_ < input_.size()) {
      char c = input_[pos_];
      if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
        ++pos_;
      } else {
        break;
      }
    }
  }

  bool AtEnd() {
    SkipWhitespace();
    return pos_ == input_.size();
  }

  bool Consume(char expected) {
    SkipWhitespace();
    if (pos_ < input_.size() && input_[pos_] == expected) {
      ++pos_;
      return true;
    }
    return false;
  }

  bool ParseString(std::string* out) {
    SkipWhitespace();
    if (pos_ >= input_.size() || input_[pos_] != '"') {
      return false;
    }
    ++pos_;
    std::string result;
    while (pos_ < input_.size()) {
      char c = input_[pos_++];
      if (c == '"') {
        if (out != nullptr) {
          *out = result;
        }
        return true;
      }
      if (c == '\\') {
        if (pos_ >= input_.size()) {
          return false;
        }
        char esc = input_[pos_++];
        switch (esc) {
          case '"':
          case '\\':
          case '/':
            result.push_back(esc);
            break;
          case 'b':
            result.push_back('\b');
            break;
          case 'f':
            result.push_back('\f');
            break;
          case 'n':
            result.push_back('\n');
            break;
          case 'r':
            result.push_back('\r');
            break;
          case 't':
            result.push_back('\t');
            break;
          case 'u': {
            if (pos_ + 4 > input_.size()) {
              return false;
            }
            for (int i = 0; i < 4; ++i) {
              char h = input_[pos_++];
              bool hex = (h >= '0' && h <= '9') || (h >= 'a' && h <= 'f') ||
                         (h >= 'A' && h <= 'F');
              if (!hex) {
                return false;
              }
            }
            result.push_back('?');
            break;
          }
          default:
            return false;
        }
      } else if (static_cast<unsigned char>(c) < 0x20) {
        return false;
      } else {
        result.push_back(c);
      }
    }
    return false;
  }

  bool ParseInt(int* out) {
    SkipWhitespace();
    if (pos_ >= input_.size()) {
      return false;
    }
    std::size_t start = pos_;
    bool negative = false;
    if (input_[pos_] == '-') {
      negative = true;
      ++pos_;
    }
    if (pos_ >= input_.size() || input_[pos_] < '0' || input_[pos_] > '9') {
      pos_ = start;
      return false;
    }
    if (input_[pos_] == '0' && pos_ + 1 < input_.size() &&
        input_[pos_ + 1] >= '0' && input_[pos_ + 1] <= '9') {
      pos_ = start;
      return false;
    }
    long long value = 0;
    while (pos_ < input_.size() && input_[pos_] >= '0' && input_[pos_] <= '9') {
      int digit = input_[pos_] - '0';
      if (value > (std::numeric_limits<long long>::max() - digit) / 10) {
        pos_ = start;
        return false;
      }
      value = value * 10 + digit;
      ++pos_;
    }
    if (pos_ < input_.size() &&
        (input_[pos_] == '.' || input_[pos_] == 'e' || input_[pos_] == 'E')) {
      pos_ = start;
      return false;
    }
    if (negative) {
      value = -value;
    }
    if (value < std::numeric_limits<int>::min() ||
        value > std::numeric_limits<int>::max()) {
      pos_ = start;
      return false;
    }
    if (out != nullptr) {
      *out = static_cast<int>(value);
    }
    return true;
  }

  bool ParseBool(bool* out) {
    SkipWhitespace();
    if (MatchLiteral("true")) {
      if (out != nullptr) {
        *out = true;
      }
      return true;
    }
    if (MatchLiteral("false")) {
      if (out != nullptr) {
        *out = false;
      }
      return true;
    }
    return false;
  }

  bool ConsumeNull() {
    SkipWhitespace();
    return MatchLiteral("null");
  }

  bool SkipValue(int depth = 0) {
    if (depth > 16) {
      return false;
    }
    SkipWhitespace();
    if (pos_ >= input_.size()) {
      return false;
    }
    char c = input_[pos_];
    if (c == '"') {
      return ParseString(nullptr);
    }
    if (c == '{') {
      ++pos_;
      if (Consume('}')) {
        return true;
      }
      while (true) {
        if (!ParseString(nullptr) || !Consume(':') || !SkipValue(depth + 1)) {
          return false;
        }
        if (Consume('}')) {
          return true;
        }
        if (!Consume(',')) {
          return false;
        }
      }
    }
    if (c == '[') {
      ++pos_;
      if (Consume(']')) {
        return true;
      }
      while (true) {
        if (!SkipValue(depth + 1)) {
          return false;
        }
        if (Consume(']')) {
          return true;
        }
        if (!Consume(',')) {
          return false;
        }
      }
    }
    if (MatchLiteral("true") || MatchLiteral("false") || MatchLiteral("null")) {
      return true;
    }
    return SkipNumber();
  }

 private:
  bool MatchLiteral(const char* literal) {
    std::size_t i = 0;
    while (literal[i] != '\0') {
      if (pos_ + i >= input_.size() || input_[pos_ + i] != literal[i]) {
        return false;
      }
      ++i;
    }
    pos_ += i;
    return true;
  }

  bool SkipNumber() {
    if (pos_ < input_.size() && input_[pos_] == '-') {
      ++pos_;
    }
    if (pos_ >= input_.size() || input_[pos_] < '0' || input_[pos_] > '9') {
      return false;
    }
    if (input_[pos_] == '0') {
      ++pos_;
    } else {
      while (pos_ < input_.size() && input_[pos_] >= '0' &&
             input_[pos_] <= '9') {
        ++pos_;
      }
    }
    if (pos_ < input_.size() && input_[pos_] == '.') {
      ++pos_;
      if (pos_ >= input_.size() || input_[pos_] < '0' || input_[pos_] > '9') {
        return false;
      }
      while (pos_ < input_.size() && input_[pos_] >= '0' &&
             input_[pos_] <= '9') {
        ++pos_;
      }
    }
    if (pos_ < input_.size() && (input_[pos_] == 'e' || input_[pos_] == 'E')) {
      ++pos_;
      if (pos_ < input_.size() &&
          (input_[pos_] == '+' || input_[pos_] == '-')) {
        ++pos_;
      }
      if (pos_ >= input_.size() || input_[pos_] < '0' || input_[pos_] > '9') {
        return false;
      }
      while (pos_ < input_.size() && input_[pos_] >= '0' &&
             input_[pos_] <= '9') {
        ++pos_;
      }
    }
    return true;
  }

  const std::string& input_;
  std::size_t pos_;
};

long long IntersectionArea(const WindowRect& a, const WindowRect& b) {
  int left = std::max(a.x, b.x);
  int top = std::max(a.y, b.y);
  int right = std::min(a.x + a.width, b.x + b.width);
  int bottom = std::min(a.y + a.height, b.y + b.height);
  if (right <= left || bottom <= top) {
    return 0;
  }
  return static_cast<long long>(right - left) *
         static_cast<long long>(bottom - top);
}

bool HasAccessibleTitleBar(const WindowRect& window,
                           const std::vector<MonitorWorkArea>& monitors) {
  for (std::size_t i = 0; i < monitors.size(); ++i) {
    const WindowRect& work = monitors[i].work_area;
    if (work.width <= 0 || work.height <= 0) {
      continue;
    }
    const int dpi = monitors[i].dpi > 0 ? monitors[i].dpi : kDefaultDpi;
    const int required_width =
        std::min(window.width, ScaleLogical(kMinVisibleTitleLogicalWidth, dpi));
    const int required_top =
        std::min(window.height, ScaleLogical(kMinVisibleTopLogicalHeight, dpi));
    const int border_tolerance = ScaleLogical(kDwmBorderLogicalTolerance, dpi);

    const int work_right = work.x + work.width;
    const int work_bottom = work.y + work.height;
    const int overlap_x =
        std::min(window.x + window.width, work_right) -
        std::max(window.x, work.x);
    if (overlap_x < required_width) {
      continue;
    }
    if (window.y >= work.y - border_tolerance &&
        window.y <= work_bottom - required_top) {
      return true;
    }
  }
  return false;
}

std::vector<MonitorWorkArea> FilterValidMonitors(
    const std::vector<MonitorWorkArea>& monitors) {
  std::vector<MonitorWorkArea> valid;
  for (std::size_t i = 0; i < monitors.size(); ++i) {
    if (monitors[i].work_area.width > 0 && monitors[i].work_area.height > 0) {
      valid.push_back(monitors[i]);
    }
  }
  return valid;
}

std::size_t FindPrimaryIndex(const std::vector<MonitorWorkArea>& monitors) {
  for (std::size_t i = 0; i < monitors.size(); ++i) {
    if (monitors[i].is_primary) {
      return i;
    }
  }
  return 0;
}

}  // namespace

bool ParseWindowStateJson(const std::string& json, WindowState* out) {
  if (out == nullptr) {
    return false;
  }
  JsonCursor cursor(json);
  if (!cursor.Consume('{')) {
    return false;
  }

  WindowState parsed;
  parsed.dpi = 0;
  bool has_x = false;
  bool has_y = false;
  bool has_width = false;
  bool has_height = false;
  int version = kSupportedVersion;

  if (!cursor.Consume('}')) {
    while (true) {
      std::string key;
      if (!cursor.ParseString(&key) || !cursor.Consume(':')) {
        return false;
      }
      if (key == "version") {
        if (!cursor.ParseInt(&version)) {
          return false;
        }
      } else if (key == "x") {
        if (cursor.ConsumeNull()) {
          has_x = false;
        } else if (cursor.ParseInt(&parsed.x)) {
          has_x = true;
        } else {
          return false;
        }
      } else if (key == "y") {
        if (cursor.ConsumeNull()) {
          has_y = false;
        } else if (cursor.ParseInt(&parsed.y)) {
          has_y = true;
        } else {
          return false;
        }
      } else if (key == "width") {
        if (!cursor.ParseInt(&parsed.width)) {
          return false;
        }
        has_width = true;
      } else if (key == "height") {
        if (!cursor.ParseInt(&parsed.height)) {
          return false;
        }
        has_height = true;
      } else if (key == "maximized") {
        if (!cursor.ParseBool(&parsed.maximized)) {
          return false;
        }
      } else if (key == "dpi") {
        if (cursor.ConsumeNull()) {
          parsed.dpi = 0;
        } else if (!cursor.ParseInt(&parsed.dpi)) {
          return false;
        }
      } else {
        if (!cursor.SkipValue()) {
          return false;
        }
      }

      if (cursor.Consume('}')) {
        break;
      }
      if (!cursor.Consume(',')) {
        return false;
      }
    }
  }

  if (!cursor.AtEnd()) {
    return false;
  }
  if (version != kSupportedVersion) {
    return false;
  }
  if (!has_width || !has_height || parsed.width <= 0 || parsed.height <= 0 ||
      parsed.width > kMaxDimension || parsed.height > kMaxDimension) {
    return false;
  }
  if (has_x && has_y && parsed.x >= kMinCoord && parsed.x <= kMaxCoord &&
      parsed.y >= kMinCoord && parsed.y <= kMaxCoord) {
    parsed.has_position = true;
  } else {
    parsed.has_position = false;
    parsed.x = 0;
    parsed.y = 0;
  }
  if (parsed.dpi < kMinDpi || parsed.dpi > kMaxDpi) {
    parsed.dpi = 0;
  }

  *out = parsed;
  return true;
}

std::string SerializeWindowStateJson(const WindowState& state) {
  std::string out = "{\"version\":1";
  if (state.has_position) {
    out += ",\"x\":";
    out += std::to_string(state.x);
    out += ",\"y\":";
    out += std::to_string(state.y);
  }
  out += ",\"width\":";
  out += std::to_string(state.width);
  out += ",\"height\":";
  out += std::to_string(state.height);
  out += ",\"maximized\":";
  out += state.maximized ? "true" : "false";
  if (state.dpi >= kMinDpi && state.dpi <= kMaxDpi) {
    out += ",\"dpi\":";
    out += std::to_string(state.dpi);
  }
  out += "}\n";
  return out;
}

WindowState ResolveWindowStateForMonitors(
    const WindowState& saved,
    const std::vector<MonitorWorkArea>& monitors,
    int min_logical_width,
    int min_logical_height) {
  WindowState resolved = saved;
  const std::vector<MonitorWorkArea> valid_monitors =
      FilterValidMonitors(monitors);
  if (valid_monitors.empty()) {
    const int dpi = resolved.dpi > 0 ? resolved.dpi : kDefaultDpi;
    resolved.dpi = dpi;
    resolved.width =
        std::max(resolved.width, ScaleLogical(min_logical_width, dpi));
    resolved.height =
        std::max(resolved.height, ScaleLogical(min_logical_height, dpi));
    return resolved;
  }

  const std::size_t primary_index = FindPrimaryIndex(valid_monitors);
  std::size_t target_index = primary_index;
  bool intersects_any = false;
  if (resolved.has_position) {
    const WindowRect saved_rect{
        resolved.x, resolved.y, resolved.width, resolved.height};
    long long best_area = 0;
    for (std::size_t i = 0; i < valid_monitors.size(); ++i) {
      const long long area =
          IntersectionArea(saved_rect, valid_monitors[i].work_area);
      if (area > best_area ||
          (area > 0 && area == best_area && valid_monitors[i].is_primary)) {
        best_area = area;
        target_index = i;
        intersects_any = true;
      }
    }
  }

  const MonitorWorkArea& target = valid_monitors[target_index];
  const int target_dpi = target.dpi > 0 ? target.dpi : kDefaultDpi;
  if (resolved.dpi > 0 && resolved.dpi != target_dpi) {
    resolved.width = RescaleDimension(resolved.width, resolved.dpi, target_dpi);
    resolved.height =
        RescaleDimension(resolved.height, resolved.dpi, target_dpi);
  }
  resolved.dpi = target_dpi;

  const int min_w = ScaleLogical(min_logical_width, target_dpi);
  const int min_h = ScaleLogical(min_logical_height, target_dpi);
  const int dwm_margin = ScaleLogical(kDwmBorderLogicalTolerance, target_dpi);
  resolved.width = std::max(resolved.width, min_w);
  resolved.height = std::max(resolved.height, min_h);
  // Allow Windows DWM invisible side/bottom borders (up to ~10 logical px per
  // edge) when preserving an already-visible window so Aero-snapped windows do
  // not lose 7px at the bottom edge on restore.
  if (resolved.width > target.work_area.width + 2 * dwm_margin) {
    resolved.width = target.work_area.width;
  }
  if (resolved.height > target.work_area.height + dwm_margin) {
    resolved.height = target.work_area.height;
  }

  if (!resolved.has_position) {
    resolved.width = std::min(resolved.width, target.work_area.width);
    resolved.height = std::min(resolved.height, target.work_area.height);
    resolved.has_position = true;
    resolved.x =
        target.work_area.x + (target.work_area.width - resolved.width) / 2;
    resolved.y =
        target.work_area.y + (target.work_area.height - resolved.height) / 2;
    return resolved;
  }

  const WindowRect candidate{
      resolved.x, resolved.y, resolved.width, resolved.height};
  if (HasAccessibleTitleBar(candidate, valid_monitors)) {
    return resolved;
  }

  resolved.width = std::min(resolved.width, target.work_area.width);
  resolved.height = std::min(resolved.height, target.work_area.height);

  // If the saved coordinates no longer intersect any active monitor (for
  // instance, after unplugging an external display), center on the primary
  // monitor so the window appears predictably in view.
  if (!intersects_any) {
    resolved.x =
        target.work_area.x + (target.work_area.width - resolved.width) / 2;
    resolved.y =
        target.work_area.y + (target.work_area.height - resolved.height) / 2;
    return resolved;
  }

  resolved.x = ClampInt(
      resolved.x, target.work_area.x,
      target.work_area.x + target.work_area.width - resolved.width);
  resolved.y = ClampInt(
      resolved.y, target.work_area.y,
      target.work_area.y + target.work_area.height - resolved.height);
  return resolved;
}

WindowState BuildDefaultWindowStateForMonitors(
    int default_logical_x,
    int default_logical_y,
    int default_logical_width,
    int default_logical_height,
    int min_logical_width,
    int min_logical_height,
    const std::vector<MonitorWorkArea>& monitors) {
  const std::vector<MonitorWorkArea> valid_monitors =
      FilterValidMonitors(monitors);
  WindowState state;
  state.has_position = true;
  state.maximized = false;

  if (valid_monitors.empty()) {
    state.dpi = kDefaultDpi;
    state.x = default_logical_x;
    state.y = default_logical_y;
    state.width = std::max(default_logical_width, min_logical_width);
    state.height = std::max(default_logical_height, min_logical_height);
    return state;
  }

  const MonitorWorkArea& primary =
      valid_monitors[FindPrimaryIndex(valid_monitors)];
  const int dpi = primary.dpi > 0 ? primary.dpi : kDefaultDpi;
  state.dpi = dpi;
  const int min_w = ScaleLogical(min_logical_width, dpi);
  const int min_h = ScaleLogical(min_logical_height, dpi);
  state.width = std::min(
      std::max(ScaleLogical(default_logical_width, dpi), min_w),
      primary.work_area.width);
  state.height = std::min(
      std::max(ScaleLogical(default_logical_height, dpi), min_h),
      primary.work_area.height);

  const int raw_x = primary.work_area.x + ScaleLogical(default_logical_x, dpi);
  const int raw_y = primary.work_area.y + ScaleLogical(default_logical_y, dpi);
  state.x = ClampInt(
      raw_x, primary.work_area.x,
      primary.work_area.x + primary.work_area.width - state.width);
  state.y = ClampInt(
      raw_y, primary.work_area.y,
      primary.work_area.y + primary.work_area.height - state.height);
  return state;
}
