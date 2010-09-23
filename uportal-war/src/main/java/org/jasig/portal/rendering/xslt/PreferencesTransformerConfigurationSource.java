/**
 * Licensed to Jasig under one or more contributor license
 * agreements. See the NOTICE file distributed with this work
 * for additional information regarding copyright ownership.
 * Jasig licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a
 * copy of the License at:
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on
 * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package org.jasig.portal.rendering.xslt;

import java.util.Hashtable;
import java.util.LinkedHashMap;
import java.util.Properties;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jasig.portal.IUserPreferencesManager;
import org.jasig.portal.StylesheetUserPreferences;
import org.jasig.portal.UserPreferences;
import org.jasig.portal.user.IUserInstance;
import org.jasig.portal.user.IUserInstanceManager;
import org.jasig.portal.utils.cache.CacheKey;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * Exposes the transformer parameter from {@link StylesheetUserPreferences#getParameterValues()}
 * 
 * @author Eric Dalquist
 * @version $Revision$
 */
public abstract class PreferencesTransformerConfigurationSource implements TransformerConfigurationSource {
    protected final Logger logger = LoggerFactory.getLogger(this.getClass());
    
    private IUserInstanceManager userInstanceManager;
    
    @Autowired
    public void setUserInstanceManager(IUserInstanceManager userInstanceManager) {
        this.userInstanceManager = userInstanceManager;
    }

    /* (non-Javadoc)
     * @see org.jasig.portal.rendering.xslt.TransformerConfigurationSource#getTransformerConfigurationKey(javax.servlet.http.HttpServletRequest, javax.servlet.http.HttpServletResponse)
     */
    @Override
    public final CacheKey getCacheKey(HttpServletRequest request, HttpServletResponse response) {
        final LinkedHashMap<String, Object> transformerParameters = this.getParameters(request, response);
        return new CacheKey(transformerParameters);
    }

    /* (non-Javadoc)
     * @see org.jasig.portal.rendering.xslt.TransformerConfigurationSource#getTransformerOutputProperties(javax.servlet.http.HttpServletRequest, javax.servlet.http.HttpServletResponse)
     */
    @Override
    public final Properties getOutputProperties(HttpServletRequest request, HttpServletResponse response) {
        return null;
    }

    /* (non-Javadoc)
     * @see org.jasig.portal.rendering.xslt.TransformerConfigurationSource#getTransformerParameters(javax.servlet.http.HttpServletRequest, javax.servlet.http.HttpServletResponse)
     */
    @Override
    public final LinkedHashMap<String, Object> getParameters(HttpServletRequest request, HttpServletResponse response) {
        final IUserInstance userInstance = this.userInstanceManager.getUserInstance(request);
        final IUserPreferencesManager preferencesManager = userInstance.getPreferencesManager();
        final UserPreferences userPreferences = preferencesManager.getUserPreferences();
        
        final StylesheetUserPreferences stylesheetUserPreferences = this.getStylesheetUserPreferences(userPreferences);
        final Hashtable<String, String> parameterValues = stylesheetUserPreferences.getParameterValues();
        
        this.logger.debug("Setting transformer parameters: {}", parameterValues);
        
        return new LinkedHashMap<String, Object>(parameterValues);
    }
    
    protected abstract StylesheetUserPreferences getStylesheetUserPreferences(UserPreferences userPreferences);
}