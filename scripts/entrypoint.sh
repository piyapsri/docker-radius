#!/bin/sh
set -e

# ==========
# ENTRYPOINT
# ==========

cat << LICENSE_ACK

# ================================================================================================ #
# Gluu License Agreement: https://github.com/GluuFederation/enterprise-edition/blob/4.0.0/LICENSE. #
# The use of Gluu Server Enterprise Edition is subject to the Gluu Support License.                #
# ================================================================================================ #

LICENSE_ACK

# check persistence type
case "${GLUU_PERSISTENCE_TYPE}" in
    ldap|couchbase|hybrid)
        ;;
    *)
        echo "unsupported GLUU_PERSISTENCE_TYPE value; please choose 'ldap', 'couchbase', or 'hybrid'"
        exit 1
        ;;
esac

# check mapping used by LDAP
if [ "${GLUU_PERSISTENCE_TYPE}" = "hybrid" ]; then
    case "${GLUU_PERSISTENCE_LDAP_MAPPING}" in
        default|user|cache|site|token)
            ;;
        *)
            echo "unsupported GLUU_PERSISTENCE_LDAP_MAPPING value; please choose 'default', 'user', 'cache', 'site', or 'token'"
            exit 1
            ;;
    esac
fi

# run wait_for functions
deps="config,secret"

if [ "${GLUU_PERSISTENCE_TYPE}" = "hybrid" ]; then
    deps="${deps},ldap,couchbase"
else
    deps="${deps},${GLUU_PERSISTENCE_TYPE}"
fi

deps="$deps,oxauth"

if [ -f /etc/redhat-release ]; then
    source scl_source enable python27 && gluu-wait --deps="$deps"
else
    gluu-wait --deps="$deps"
fi

# run Python entrypoint
if [ ! -f /deploy/touched ]; then
    if [ -f /etc/redhat-release ]; then
        source scl_source enable python27 && python /app/scripts/entrypoint.py
    else
        python /app/scripts/entrypoint.py
    fi

    touch /deploy/touched
fi

# run Radius server
exec java \
    -XX:+DisableExplicitGC \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=$GLUU_MAX_RAM_PERCENTAGE \
    -Dpython.home=/opt/jython \
    -Dlog4j.configurationFile=file:/etc/gluu/conf/radius/gluu-radius-logging.xml \
    -Dradius.home=/opt/gluu/radius \
    -Dradius.base=/opt/gluu/radius \
    -Djava.io.tmpdir=/tmp \
    -cp /opt/gluu/radius/super-gluu-radius-server.jar \
    org.gluu.radius.ServerEntry /etc/gluu/conf/radius/gluu-radius.properties
