// Check 1: Anti-pattern for CPP object property bindings

#include <QtQmlCompiler/qqmlsa.h>

class CppObjectBindingCheck : public QQmlSA::ElementPass
{
public:
    CppObjectBindingCheck(QQmlSA::PassManager *manager)
        : QQmlSA::ElementPass(manager)
    {}

    bool shouldRun(const QQmlSA::Element &element) override;

    void run(const QQmlSA::Element &element) override;

private:
    void cppObjectReference(script, objectId, propertyName);

    bool isCppObjectBinding(const QString &script, const QQmlSA::Element &element) const;

    bool isCppRegisteredObject(const QString &objectId, const QQmlSA::Element &element) const;

    bool isCppRegisteredType(const QString &typeName) const;

    bool parseCppObjectReference(const QString &script,
                                 QString &objectId,
                                 QString &propertyName) const;

    bool isEnumBinding(const QString &script, const QQmlSA::Element &element) const;

    void emitCppBindingWarning(const QQmlSA::Binding &binding,
                               const QString &objectId,
                               const QString &propertyName);

    QQmlSA::Element getRootElement(const QQmlSA::Binding &binding) const;
};
