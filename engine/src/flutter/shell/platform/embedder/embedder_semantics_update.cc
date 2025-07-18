// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/embedder/embedder_semantics_update.h"

namespace {

// TODO(hangyujin): Update these two functions once the SemanticsFlags in
// dart:ui are updated to use tristate/quad-state flags for properties like
// isChecked and isSelected.
FlutterCheckState ToFlutterCheckState(bool is_not_none,
                                      bool is_true,
                                      bool is_mixed) {
  if (!is_not_none) {
    return kFlutterCheckStateNone;
  }
  if (is_true) {
    return kFlutterCheckStateTrue;
  }
  if (is_mixed) {
    return kFlutterCheckStateMixed;
  }
  return kFlutterCheckStateFalse;
}

FlutterTristate ToFlutterTristate(bool is_not_none, bool is_true) {
  if (!is_not_none) {
    return kFlutterTristateNone;
  }
  if (is_true) {
    return kFlutterTristateTrue;
  }
  return kFlutterTristateFalse;
}

std::unique_ptr<FlutterSemanticsFlags> ConvertToFlutterSemanticsFlags(
    const flutter::SemanticsFlags& source) {
  return std::make_unique<FlutterSemanticsFlags>(FlutterSemanticsFlags{
      .is_checked = ToFlutterCheckState(
          source.hasCheckedState, source.isChecked, source.isCheckStateMixed),
      .is_selected =
          ToFlutterTristate(source.hasSelectedState, source.isSelected),
      .is_enabled = ToFlutterTristate(source.hasEnabledState, source.isEnabled),
      .is_toggled = ToFlutterTristate(source.hasToggledState, source.isToggled),
      .is_expanded =
          ToFlutterTristate(source.hasExpandedState, source.isExpanded),
      .is_required =
          ToFlutterTristate(source.hasRequiredState, source.isRequired),
      .is_focused = ToFlutterTristate(source.isFocusable, source.isFocused),
      .is_button = source.isButton,
      .is_text_field = source.isTextField,
      .is_in_mutually_exclusive_group = source.isInMutuallyExclusiveGroup,
      .is_header = source.isHeader,
      .is_obscured = source.isObscured,
      .scopes_route = source.scopesRoute,
      .names_route = source.namesRoute,
      .is_hidden = source.isHidden,
      .is_image = source.isImage,
      .is_live_region = source.isLiveRegion,
      .has_implicit_scrolling = source.hasImplicitScrolling,
      .is_multiline = source.isMultiline,
      .is_read_only = source.isReadOnly,
      .is_link = source.isLink,
      .is_slider = source.isSlider,
      .is_keyboard_key = source.isKeyboardKey,
  });
}

}  // namespace

namespace flutter {

EmbedderSemanticsUpdate::EmbedderSemanticsUpdate(
    const SemanticsNodeUpdates& nodes,
    const CustomAccessibilityActionUpdates& actions) {
  for (const auto& value : nodes) {
    AddNode(value.second);
  }

  for (const auto& value : actions) {
    AddAction(value.second);
  }

  update_ = {
      .struct_size = sizeof(FlutterSemanticsUpdate),
      .nodes_count = nodes_.size(),
      .nodes = nodes_.data(),
      .custom_actions_count = actions_.size(),
      .custom_actions = actions_.data(),
  };
}

// This function is for backward compatibility and contains only a subset of
// the flags. New flags will be added only to `FlutterSemanticsFlags`, not
// `FlutterSemanticsFlag`.
FlutterSemanticsFlag SemanticsFlagsToInt(const SemanticsFlags& flags) {
  int result = 0;

  if (flags.hasCheckedState) {
    result |= (1 << 0);
  }
  if (flags.isChecked) {
    result |= (1 << 1);
  }
  if (flags.isSelected) {
    result |= (1 << 2);
  }
  if (flags.isButton) {
    result |= (1 << 3);
  }
  if (flags.isTextField) {
    result |= (1 << 4);
  }
  if (flags.isFocused) {
    result |= (1 << 5);
  }
  if (flags.hasEnabledState) {
    result |= (1 << 6);
  }
  if (flags.isEnabled) {
    result |= (1 << 7);
  }
  if (flags.isInMutuallyExclusiveGroup) {
    result |= (1 << 8);
  }
  if (flags.isHeader) {
    result |= (1 << 9);
  }
  if (flags.isObscured) {
    result |= (1 << 10);
  }
  if (flags.scopesRoute) {
    result |= (1 << 11);
  }
  if (flags.namesRoute) {
    result |= (1 << 12);
  }
  if (flags.isHidden) {
    result |= (1 << 13);
  }
  if (flags.isImage) {
    result |= (1 << 14);
  }
  if (flags.isLiveRegion) {
    result |= (1 << 15);
  }
  if (flags.hasToggledState) {
    result |= (1 << 16);
  }
  if (flags.isToggled) {
    result |= (1 << 17);
  }
  if (flags.hasImplicitScrolling) {
    result |= (1 << 18);
  }
  if (flags.isMultiline) {
    result |= (1 << 19);
  }
  if (flags.isReadOnly) {
    result |= (1 << 20);
  }
  if (flags.isFocusable) {
    result |= (1 << 21);
  }
  if (flags.isLink) {
    result |= (1 << 22);
  }
  if (flags.isSlider) {
    result |= (1 << 23);
  }
  if (flags.isKeyboardKey) {
    result |= (1 << 24);
  }
  if (flags.isCheckStateMixed) {
    result |= (1 << 25);
  }
  if (flags.hasExpandedState) {
    result |= (1 << 26);
  }
  if (flags.isExpanded) {
    result |= (1 << 27);
  }
  if (flags.hasSelectedState) {
    result |= (1 << 28);
  }
  if (flags.hasRequiredState) {
    result |= (1 << 29);
  }
  if (flags.isRequired) {
    result |= (1 << 30);
  }

  return static_cast<FlutterSemanticsFlag>(result);
}

void EmbedderSemanticsUpdate::AddNode(const SemanticsNode& node) {
  SkMatrix transform = node.transform.asM33();
  FlutterTransformation flutter_transform{
      transform.get(SkMatrix::kMScaleX), transform.get(SkMatrix::kMSkewX),
      transform.get(SkMatrix::kMTransX), transform.get(SkMatrix::kMSkewY),
      transform.get(SkMatrix::kMScaleY), transform.get(SkMatrix::kMTransY),
      transform.get(SkMatrix::kMPersp0), transform.get(SkMatrix::kMPersp1),
      transform.get(SkMatrix::kMPersp2)};

  // Do not add new members to FlutterSemanticsNode.
  // This would break the forward compatibility of FlutterSemanticsUpdate.
  // All new members must be added to FlutterSemanticsNode2 instead.
  nodes_.push_back({
      sizeof(FlutterSemanticsNode),
      node.id,
      SemanticsFlagsToInt(node.flags),
      static_cast<FlutterSemanticsAction>(node.actions),
      node.textSelectionBase,
      node.textSelectionExtent,
      node.scrollChildren,
      node.scrollIndex,
      node.scrollPosition,
      node.scrollExtentMax,
      node.scrollExtentMin,
      0.0,
      0.0,
      node.label.c_str(),
      node.hint.c_str(),
      node.value.c_str(),
      node.increasedValue.c_str(),
      node.decreasedValue.c_str(),
      static_cast<FlutterTextDirection>(node.textDirection),
      FlutterRect{node.rect.fLeft, node.rect.fTop, node.rect.fRight,
                  node.rect.fBottom},
      flutter_transform,
      node.childrenInTraversalOrder.size(),
      node.childrenInTraversalOrder.data(),
      node.childrenInHitTestOrder.data(),
      node.customAccessibilityActions.size(),
      node.customAccessibilityActions.data(),
      node.platformViewId,
      node.tooltip.c_str(),
  });
}

void EmbedderSemanticsUpdate::AddAction(
    const CustomAccessibilityAction& action) {
  // Do not add new members to FlutterSemanticsCustomAction.
  // This would break the forward compatibility of FlutterSemanticsUpdate.
  // All new members must be added to FlutterSemanticsCustomAction2 instead.
  actions_.push_back({
      sizeof(FlutterSemanticsCustomAction),
      action.id,
      static_cast<FlutterSemanticsAction>(action.overrideId),
      action.label.c_str(),
      action.hint.c_str(),
  });
}

EmbedderSemanticsUpdate::~EmbedderSemanticsUpdate() {}

EmbedderSemanticsUpdate2::EmbedderSemanticsUpdate2(
    int64_t view_id,
    const SemanticsNodeUpdates& nodes,
    const CustomAccessibilityActionUpdates& actions) {
  nodes_.reserve(nodes.size());
  flags_.reserve(nodes.size());
  node_pointers_.reserve(nodes.size());
  actions_.reserve(actions.size());
  action_pointers_.reserve(actions.size());

  for (const auto& value : nodes) {
    AddNode(value.second);
  }

  for (const auto& value : actions) {
    AddAction(value.second);
  }

  for (size_t i = 0; i < nodes_.size(); i++) {
    node_pointers_.push_back(&nodes_[i]);
  }

  for (size_t i = 0; i < actions_.size(); i++) {
    action_pointers_.push_back(&actions_[i]);
  }

  update_ = {.struct_size = sizeof(FlutterSemanticsUpdate2),
             .node_count = node_pointers_.size(),
             .nodes = node_pointers_.data(),
             .custom_action_count = action_pointers_.size(),
             .custom_actions = action_pointers_.data(),
             .view_id = view_id};
}

EmbedderSemanticsUpdate2::~EmbedderSemanticsUpdate2() {}

void EmbedderSemanticsUpdate2::AddNode(const SemanticsNode& node) {
  SkMatrix transform = node.transform.asM33();
  FlutterTransformation flutter_transform{
      transform.get(SkMatrix::kMScaleX), transform.get(SkMatrix::kMSkewX),
      transform.get(SkMatrix::kMTransX), transform.get(SkMatrix::kMSkewY),
      transform.get(SkMatrix::kMScaleY), transform.get(SkMatrix::kMTransY),
      transform.get(SkMatrix::kMPersp0), transform.get(SkMatrix::kMPersp1),
      transform.get(SkMatrix::kMPersp2)};

  auto label_attributes = CreateStringAttributes(node.labelAttributes);
  auto hint_attributes = CreateStringAttributes(node.hintAttributes);
  auto value_attributes = CreateStringAttributes(node.valueAttributes);
  auto increased_value_attributes =
      CreateStringAttributes(node.increasedValueAttributes);
  auto decreased_value_attributes =
      CreateStringAttributes(node.decreasedValueAttributes);
  flags_.emplace_back(ConvertToFlutterSemanticsFlags(node.flags));

  nodes_.push_back({
      sizeof(FlutterSemanticsNode2),
      node.id,
      SemanticsFlagsToInt(node.flags),
      static_cast<FlutterSemanticsAction>(node.actions),
      node.textSelectionBase,
      node.textSelectionExtent,
      node.scrollChildren,
      node.scrollIndex,
      node.scrollPosition,
      node.scrollExtentMax,
      node.scrollExtentMin,
      0.0,
      0.0,
      node.label.c_str(),
      node.hint.c_str(),
      node.value.c_str(),
      node.increasedValue.c_str(),
      node.decreasedValue.c_str(),
      static_cast<FlutterTextDirection>(node.textDirection),
      FlutterRect{node.rect.fLeft, node.rect.fTop, node.rect.fRight,
                  node.rect.fBottom},
      flutter_transform,
      node.childrenInTraversalOrder.size(),
      node.childrenInTraversalOrder.data(),
      node.childrenInHitTestOrder.data(),
      node.customAccessibilityActions.size(),
      node.customAccessibilityActions.data(),
      node.platformViewId,
      node.tooltip.c_str(),
      label_attributes.count,
      label_attributes.attributes,
      hint_attributes.count,
      hint_attributes.attributes,
      value_attributes.count,
      value_attributes.attributes,
      increased_value_attributes.count,
      increased_value_attributes.attributes,
      decreased_value_attributes.count,
      decreased_value_attributes.attributes,
      flags_.back().get(),
  });
}

void EmbedderSemanticsUpdate2::AddAction(
    const CustomAccessibilityAction& action) {
  actions_.push_back({
      sizeof(FlutterSemanticsCustomAction2),
      action.id,
      static_cast<FlutterSemanticsAction>(action.overrideId),
      action.label.c_str(),
      action.hint.c_str(),
  });
}

EmbedderSemanticsUpdate2::EmbedderStringAttributes
EmbedderSemanticsUpdate2::CreateStringAttributes(
    const StringAttributes& attributes) {
  // Minimize allocations if attributes are empty.
  if (attributes.empty()) {
    return {.count = 0, .attributes = nullptr};
  }

  // Translate the engine attributes to embedder attributes.
  // The result vector's data is returned by this method.
  // The result vector will be owned by |node_string_attributes_|
  // so that the embedder attributes are cleaned up at the end of the
  // semantics update callback when when the |EmbedderSemanticsUpdate2|
  // is destroyed.
  auto result = std::make_unique<std::vector<const FlutterStringAttribute*>>();
  result->reserve(attributes.size());

  for (const auto& attribute : attributes) {
    auto embedder_attribute = std::make_unique<FlutterStringAttribute>();
    embedder_attribute->struct_size = sizeof(FlutterStringAttribute);
    embedder_attribute->start = attribute->start;
    embedder_attribute->end = attribute->end;

    switch (attribute->type) {
      case StringAttributeType::kLocale: {
        std::shared_ptr<flutter::LocaleStringAttribute> locale_attribute =
            std::static_pointer_cast<flutter::LocaleStringAttribute>(attribute);

        auto embedder_locale = std::make_unique<FlutterLocaleStringAttribute>();
        embedder_locale->struct_size = sizeof(FlutterLocaleStringAttribute);
        embedder_locale->locale = locale_attribute->locale.c_str();
        locale_attributes_.push_back(std::move(embedder_locale));

        embedder_attribute->type = FlutterStringAttributeType::kLocale;
        embedder_attribute->locale = locale_attributes_.back().get();
        break;
      }
      case flutter::StringAttributeType::kSpellOut: {
        // All spell out attributes are identical and share a lazily created
        // instance.
        if (!spell_out_attribute_) {
          auto spell_out_attribute_ =
              std::make_unique<FlutterSpellOutStringAttribute>();
          spell_out_attribute_->struct_size =
              sizeof(FlutterSpellOutStringAttribute);
        }

        embedder_attribute->type = FlutterStringAttributeType::kSpellOut;
        embedder_attribute->spell_out = spell_out_attribute_.get();
        break;
      }
    }

    string_attributes_.push_back(std::move(embedder_attribute));
    result->push_back(string_attributes_.back().get());
  }

  node_string_attributes_.push_back(std::move(result));

  return {
      .count = node_string_attributes_.back()->size(),
      .attributes = node_string_attributes_.back()->data(),
  };
}

}  // namespace flutter
