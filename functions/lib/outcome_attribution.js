function millis(value) {
  const result = new Date(value).valueOf();
  return Number.isFinite(result) ? result : null;
}

/** D-160: attribute only delivered decisions to post-deployment outcomes. */
export function attributeCheckboxOutcome({
  experimentId,
  decisionId,
  target,
  deliveredAt,
  measurementWindowDays = 1,
  deliveryState,
  events = [],
}) {
  if (!experimentId || !decisionId || !target || !deliveredAt) throw new Error('attribution_input_invalid');
  const start = millis(deliveredAt);
  const end = start + measurementWindowDays * 86400000;
  const qualified = deliveryState === 'sent';
  const completions = qualified ? events.filter((event) => {
    const at = millis(event.occurredAt || event.taskdate);
    return event.type === 'checkbox' && event.target === target && event.postDeployment === true &&
      at >= start && at <= end && event.checked === true;
  }) : [];

  return {
    experimentId,
    decisionId,
    target,
    deliveryState,
    primaryOutcome: {
      name: 'checkbox_completion_quantity',
      completionCount: completions.length,
      measuredWithinWindow: qualified,
    },
    secondarySignals: qualified ? events.filter((event) =>
      event.postDeployment === true && millis(event.occurredAt || event.taskdate) >= start &&
      millis(event.occurredAt || event.taskdate) <= end && event.type !== 'checkbox') : [],
    attributionQualified: qualified,
  };
}

export function buildLearningExample({ attribution, modelVersion }) {
  if (!attribution?.attributionQualified || !modelVersion) return null;
  return {
    experimentId: attribution.experimentId,
    decisionId: attribution.decisionId,
    target: attribution.target,
    primaryOutcome: attribution.primaryOutcome,
    modelVersion,
    source: 'post_deployment_attribution',
  };
}

