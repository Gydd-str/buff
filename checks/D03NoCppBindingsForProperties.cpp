bool CppObjectBindingCheck::shouldRun(const QQmlSA::Element &element)
{
    // Run on all elements that have property bindings
    return !element.propertyBindings().isEmpty();
}

void CppObjectBindingCheck::run(const QQmlSA::Element &element)
{
    checkCppObjectBindings(element);
}

void CppObjectBindingCheck::cppObjectReference(script, objectId, propertyName)
{
    // Check if it's an enum - these are allowed
    if (!isEnumBinding(script, element)) {
        emitCppBindingWarning(binding, objectId, propertyName);
    }
}

bool CppObjectBindingCheck::isCppObjectBinding(const QString &script,
                                               const QQmlSA::Element &element) const
{
    // Pattern: objectId.propertyName
    QRegularExpression cppRefPattern(R"(^([a-zA-Z_][a-zA-Z0-9_]*\s*\.\s*[a-zA-Z_][a-zA-Z0-9_]*))");
    QRegularExpressionMatch match = cppRefPattern.match(script);

    if (!match.hasMatch()) {
        return false;
    }

    // Check if the referenced object is a C++ registered object
    QString objectId = script.split('.').first().trimmed();
    return isCppRegisteredObject(objectId, element);
}

bool CppObjectBindingCheck::isCppRegisteredObject(const QString &objectId,
                                                  const QQmlSA::Element &element) const
{
    auto scope = element.parentScope();
    while (scope.has_value()) {
        const auto children = scope->childScopes();
        auto found = std::any_of(children.begin(), children.end(), [&](const auto &child) {
            return child.id() == objectId && isCppRegisteredType(child.baseTypeName());
        });
        if (found)
            return true;
        scope = scope->parentScope();
    }
    return false;
}

bool CppObjectBindingCheck::isCppRegisteredType(const QString &typeName) const
{
    // Common C++ registered types in Qt
    QStringList cppTypes = {
        "QObject",
        "QQuickItem",
        "QAbstractListModel",
        "QSortFilterProxyModel",
        "QTimer",
        "QSettings",
        "QFileSystemWatcher",
        "QNetworkAccessManager",
        // Add more C++ types as needed
    };

    // Check if it starts with Q (Qt convention) or is in known C++ types
    return typeName.startsWith('Q') || cppTypes.contains(typeName);
}

bool CppObjectBindingCheck::parseCppObjectReference(const QString &script,
                                                    QString &objectId,
                                                    QString &propertyName) const
{
    QStringList parts = script.split('.');
    if (parts.size() >= 2) {
        objectId = parts[0].trimmed();
        propertyName = parts[1].trimmed();
        return true;
    }
    return false;
}

bool CppObjectBindingCheck::isEnumBinding(const QString &script,
                                          const QQmlSA::Element &element) const
{
    // Check if the property being accessed is an enum
    QString objectId, propertyName;
    if (parseCppObjectReference(script, objectId, propertyName)) {
        // Common enum patterns in Qt
        return propertyName.contains("State") || propertyName.contains("Mode")
               || propertyName.contains("Type") || propertyName.contains("Policy")
               || script.contains("::"); // Qualified enum access
    }
    return false;
}

void CppObjectBindingCheck::emitCppBindingWarning(const QQmlSA::Binding &binding,
                                                  const QString &objectId,
                                                  const QString &propertyName)
{
    QString aliasName = QString("als_%1_%2").arg(objectId, propertyName);
    QString message = QString(
        "Property binding to C++ object detected. Consider using property alias instead.");

    // Create fix action instead of string hint
    QQmlSA::FixSuggestion fixSuggestion;
    fixSuggestion.setHint(QString("Add property alias: property alias %1: %2.%3")
                              .arg(aliasName, objectId, propertyName));

    // Add the alias property at the root level
    auto rootElement = getRootElement(binding);
    QQmlSA::SourceLocation insertLocation = rootElement.sourceLocation();
    insertLocation.setOffset(insertLocation.offset() + insertLocation.length()
                             - 1); // Before closing brace

    fixSuggestion.addInsertion(insertLocation,
                               QString("\n    property alias %1: %2.%3")
                                   .arg(aliasName, objectId, propertyName));

    // Replace the binding with alias reference
    fixSuggestion.addReplacement(binding.sourceLocation(), aliasName);

    passManager()->emitWarning(message,
                               qmlsaCppBindingAntiPattern,
                               binding.sourceLocation(),
                               fixSuggestion);
}

QQmlSA::Element CppObjectBindingCheck::getRootElement(const QQmlSA::Binding &binding) const
{
    auto element = binding.containingElement();
    while (element.parentScope().has_value()) {
        element = element.parentScope().value();
    }
    return element;
}
